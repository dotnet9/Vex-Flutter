import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

final class OpenedDocument {
  const OpenedDocument(this.name, this.text, this.path);
  final String name, text;
  final String? path;
}

final class FileConflict implements Exception {
  const FileConflict();
  @override
  String toString() => 'FileConflict: the file was modified externally.';
}

abstract interface class DocumentFileService {
  Future<OpenedDocument?> pick();
  Future<OpenedDocument> read(String path);
  Future<List<String>?> folder();
  Future<String?> saveAs(String name, Uint8List bytes, {String? dialogTitle});
  Future<void> write(String path, String text, {String? expected});
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
    // Mobile pickers return a cache copy. Save through the system document picker.
    final path = Platform.isAndroid || Platform.isIOS ? null : file.path;
    return OpenedDocument(
      file.name,
      utf8.decode(bytes).replaceFirst('\uFEFF', ''),
      path,
    );
  }

  @override
  Future<OpenedDocument> read(String path) async => OpenedDocument(
    p.basename(path),
    (await File(path).readAsString()).replaceFirst('\uFEFF', ''),
    path,
  );

  @override
  Future<List<String>?> folder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return null;
    final files = <String>[];
    await for (final entity in Directory(path).list(followLinks: false)) {
      if (entity is File &&
          [
            '.md',
            '.markdown',
          ].contains(p.extension(entity.path).toLowerCase())) {
        files.add(entity.path);
      }
    }
    return files..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  Future<String?> saveAs(
    String name,
    Uint8List bytes, {
    String? dialogTitle,
  }) async {
    final destination = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
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
  Future<void> write(String path, String text, {String? expected}) async {
    if (expected != null &&
        await File(path).exists() &&
        (await File(path).readAsString()).replaceFirst('\uFEFF', '') !=
            expected) {
      throw const FileConflict();
    }
    await _atomicWrite(path, utf8.encode(text));
  }

  Future<void> _atomicWrite(String path, List<int> bytes) async {
    final target = File(path), stamp = DateTime.now().microsecondsSinceEpoch;
    final pending = File('$path.texweft-$stamp.tmp');
    final backup = File('$path.texweft-$stamp.bak');
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
