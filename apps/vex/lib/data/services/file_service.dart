import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../domain/file_preferences.dart';
import 'document_codec.dart';

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
  Future<OpenedFolder?> folder();
  Future<OpenedFolder> readFolder(String path);
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
  @override
  Future<OpenedDocument?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final decoded = await decodeDocument(bytes);
    // Mobile pickers return a cache copy. Save through the system document picker.
    final path = Platform.isAndroid || Platform.isIOS ? null : file.path;
    return OpenedDocument(
      file.name,
      decoded.text,
      path,
      format: decoded.format,
    );
  }

  @override
  Future<OpenedDocument> read(String path) async {
    final decoded = await decodeDocument(await File(path).readAsBytes());
    return OpenedDocument(
      p.basename(path),
      decoded.text,
      path,
      format: decoded.format,
    );
  }

  @override
  Future<OpenedFolder?> folder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return null;
    return readFolder(path);
  }

  @override
  Future<OpenedFolder> readFolder(String path) async {
    final files = <String>[];
    final directories = <String>[];
    await for (final entity in Directory(
      path,
    ).list(recursive: true, followLinks: false)) {
      if (entity is Directory) directories.add(entity.path);
      if (entity is File &&
          [
            '.md',
            '.markdown',
            '.txt',
          ].contains(p.extension(entity.path).toLowerCase())) {
        files.add(entity.path);
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
