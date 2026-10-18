import 'dart:typed_data';

import 'package:vex/data/repositories/recovery_repository.dart';
import 'package:vex/data/repositories/settings_repository.dart';
import 'package:vex/data/services/file_service.dart';
import 'package:vex/data/services/document_codec.dart';
import 'package:vex/domain/file_preferences.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

final class MemorySettings implements SettingsRepository {
  Map<String, Object?> value = {};
  @override
  Future<Map<String, Object?>> load() async => value;
  @override
  Future<void> save(Map<String, Object?> value) async {
    this.value = value;
  }
}

final class MemoryRecovery implements RecoveryRepository {
  List<Map<String, Object?>> value = [];
  Future<void> Function()? beforeSave;
  @override
  Future<List<Map<String, Object?>>> load() async => value;
  @override
  Future<void> save(List<Map<String, Object?>> documents) async {
    if (beforeSave != null) await beforeSave!();
    value = documents;
  }
}

final class MemoryFiles implements DocumentFileService {
  final content = <String, String>{};
  Future<void> Function()? beforeWrite;
  Future<void> Function(String path)? beforeRead;
  final readPaths = <String>[];
  String? nextSave = '/notes/saved.md';
  String? folderPath = '/notes';
  List<String> folderDirectories = [];
  Uint8List? lastSavedBytes;
  String? lastSaveName, lastInitialDirectory;
  @override
  Future<OpenedDocument?> pick() async => null;
  @override
  Future<OpenedFolder?> folder() async =>
      folderPath == null ? null : readFolder(folderPath!);
  @override
  Future<OpenedFolder> readFolder(String path) async => OpenedFolder(
    path,
    files: content.keys.toList(),
    directories: folderDirectories,
  );
  @override
  Future<OpenedDocument> read(String path) async {
    readPaths.add(path);
    if (beforeRead != null) await beforeRead!(path);
    return OpenedDocument(path.split('/').last, content[path]!, path);
  }

  @override
  Future<String?> saveAs(
    String name,
    Uint8List bytes, {
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    lastSavedBytes = bytes;
    lastSaveName = name;
    lastInitialDirectory = initialDirectory;
    if (nextSave != null &&
        ['md', 'markdown', 'txt'].contains(name.split('.').last)) {
      content[nextSave!] = (await decodeDocument(bytes)).text;
    }
    return nextSave;
  }

  @override
  Future<void> write(
    String path,
    String text, {
    String? expected,
    TextFileFormat format = const TextFileFormat(),
  }) async {
    if (content[path] != expected) throw const FileConflict();
    await beforeWrite?.call();
    content[path] = text;
  }
}

WorkspaceViewModel fakeWorkspace() => WorkspaceViewModel(
  files: MemoryFiles(),
  settings: MemorySettings(),
  recovery: MemoryRecovery(),
);
