import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../domain/file_preferences.dart';
import 'document_codec.dart';

bool isSystemDocument(String? path) =>
    path != null && path.startsWith('vex-document:');
const defaultExcludedDirectories = {
  '.git',
  '.dart_tool',
  '.idea',
  '.gradle',
  'build',
  'node_modules',
  'Pods',
  '.symlinks',
};

final class OpenedDocument {
  const OpenedDocument(
    this.name,
    this.text,
    this.path, {
    this.format = const TextFileFormat(),
  });
  final String name, text;
  final String? path;
  final TextFileFormat format;
}

final class OpenedFolder {
  OpenedFolder(
    this.path, {
    required List<String> files,
    List<String> directories = const [],
  }) : files = List.unmodifiable(files),
       directories = List.unmodifiable(directories);
  final String path;
  final List<String> files, directories;
}

final class FileConflict implements Exception {
  const FileConflict();
  @override
  String toString() => 'FileConflict: the file was modified externally.';
}

abstract interface class DocumentFileService {
  Future<OpenedDocument?> pick();
  Future<OpenedDocument> read(String path);
  Future<String> readPreview(String path);
  Future<OpenedFolder?> folder({
    Set<String> excludedDirectories = defaultExcludedDirectories,
    void Function(OpenedFolder)? onProgress,
    bool Function()? cancelled,
  });
  Future<OpenedFolder> readFolder(
    String path, {
    Set<String> excludedDirectories = defaultExcludedDirectories,
    void Function(OpenedFolder)? onProgress,
    bool Function()? cancelled,
  });
  Future<String?> saveAs(
    String name,
    Uint8List bytes, {
    String? dialogTitle,
    String? initialDirectory,
  });
  Future<void> write(
    String path,
    String text, {
    String? expected,
    TextFileFormat format = const TextFileFormat(),
  });
}

final class NativeDocumentFileService implements DocumentFileService {
  static const documents = MethodChannel('vex/documents');

  Future<OpenedDocument> _systemRead(String location) async {
    final result = await documents.invokeMapMethod<String, Object?>(
      'readDocument',
      {'location': location},
    );
    if (result == null ||
        result['bytes'] is! Uint8List ||
        result['name'] is! String) {
      throw const FormatException('Invalid system document');
    }
    final decoded = await decodeDocument(result['bytes']! as Uint8List);
    return OpenedDocument(
      result['name']! as String,
      decoded.text,
      location,
      format: decoded.format,
    );
  }

  @override
  Future<String> readPreview(String path) async {
    final handle = await File(path).open();
    try {
      var bytes = await handle.read(8192);
      // End at a complete line when truncating a multibyte-encoded document.
      if (bytes.length == 8192) {
        final newline = bytes.lastIndexOf(10);
        if (newline > 0) bytes = bytes.sublist(0, newline);
      }
      return (await decodeDocument(bytes)).text;
    } finally {
      await handle.close();
    }
  }

  @override
  Future<OpenedDocument?> pick() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await documents.invokeMapMethod<String, Object?>(
        'pickDocument',
      );
      if (result == null) return null;
      final decoded = await decodeDocument(result['bytes']! as Uint8List);
      return OpenedDocument(
        result['name']! as String,
        decoded.text,
        result['location'] as String?,
        format: decoded.format,
      );
    }
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final decoded = await decodeDocument(bytes);
    return OpenedDocument(
      file.name,
      decoded.text,
      file.path,
      format: decoded.format,
    );
  }

  @override
  Future<OpenedDocument> read(String path) async {
    if (isSystemDocument(path)) return _systemRead(path);
    final decoded = await decodeDocument(await File(path).readAsBytes());
    return OpenedDocument(
      p.basename(path),
      decoded.text,
      path,
      format: decoded.format,
    );
  }

  @override
  Future<OpenedFolder?> folder({
    Set<String> excludedDirectories = defaultExcludedDirectories,
    void Function(OpenedFolder)? onProgress,
    bool Function()? cancelled,
  }) async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return null;
    return readFolder(
      path,
      excludedDirectories: excludedDirectories,
      onProgress: onProgress,
      cancelled: cancelled,
    );
  }

  @override
  Future<OpenedFolder> readFolder(
    String path, {
    Set<String> excludedDirectories = defaultExcludedDirectories,
    void Function(OpenedFolder)? onProgress,
    bool Function()? cancelled,
  }) async {
    final files = <String>[];
    final directories = <String>[];
    final queue = <String>[path],
        excluded = excludedDirectories
            .map((name) => name.toLowerCase())
            .toSet();
    var visited = 0;
    for (var index = 0; index < queue.length; index++) {
      if (cancelled?.call() == true) break;
      try {
        await for (final entity in Directory(
          queue[index],
        ).list(followLinks: false)) {
          if (cancelled?.call() == true) break;
          if (entity is Directory &&
              !excluded.contains(p.basename(entity.path).toLowerCase())) {
            directories.add(entity.path);
            queue.add(entity.path);
          }
          if (entity is File &&
              [
                '.md',
                '.markdown',
                '.txt',
              ].contains(p.extension(entity.path).toLowerCase())) {
            files.add(entity.path);
          }
          if (++visited % 128 == 0) {
            onProgress?.call(
              OpenedFolder(path, files: files, directories: directories),
            );
            await Future<void>.delayed(Duration.zero);
          }
        }
      } on FileSystemException {
        if (index == 0) rethrow;
      }
    }
    return OpenedFolder(path, files: files, directories: directories);
  }

  @override
  Future<String?> saveAs(
    String name,
    Uint8List bytes, {
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await documents.invokeMapMethod<String, Object?>(
        'saveDocument',
        {'name': name, 'bytes': bytes},
      );
      return result?['location'] as String?;
    }
    final destination = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [p.extension(name).replaceFirst('.', '')],
      bytes: bytes,
    );
    if (destination == null) return null;
    return destination.scheme == 'file'
        ? destination.toFilePath()
        : destination.toString();
  }

  @override
  Future<void> write(
    String path,
    String text, {
    String? expected,
    TextFileFormat format = const TextFileFormat(),
  }) async {
    final bytes = await encodeDocument(text, format);
    if (isSystemDocument(path)) {
      if (expected != null &&
          (await read(path)).text != normalizeNewlines(expected)) {
        throw const FileConflict();
      }
      await documents.invokeMethod<void>('writeDocument', {
        'location': path,
        'bytes': bytes,
      });
      return;
    }
    if (expected != null &&
        (!await File(path).exists() ||
            (await read(path)).text != normalizeNewlines(expected))) {
      throw const FileConflict();
    }
    await _atomicWrite(path, bytes);
  }

  Future<void> _atomicWrite(String path, List<int> bytes) async {
    final target = File(path), stamp = DateTime.now().microsecondsSinceEpoch;
    final pending = File('$path.vex-$stamp.tmp');
    final backup = File('$path.vex-$stamp.bak');
    await pending.writeAsBytes(bytes, flush: true);
    var backedUp = false;
    try {
      if (await target.exists()) {
        await target.rename(backup.path);
        backedUp = true;
      }
      await pending.rename(path);
    } catch (_) {
      if (backedUp && !await target.exists()) await backup.rename(path);
      rethrow;
    } finally {
      if (await pending.exists()) await pending.delete();
    }
    if (backedUp && await backup.exists()) await backup.delete();
  }
}
