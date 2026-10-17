import 'dart:typed_data';

import 'package:texweft/data/repositories/recovery_repository.dart';
import 'package:texweft/data/repositories/settings_repository.dart';
import 'package:texweft/data/services/file_service.dart';
import 'package:texweft/ui/workspace/workspace_view_model.dart';

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
  @override
  Future<List<Map<String, Object?>>> load() async => value;
  @override
  Future<void> save(List<Map<String, Object?>> documents) async {
    value = documents;
  }
}

final class MemoryFiles implements DocumentFileService {
  final content = <String, String>{};
  Future<void> Function()? beforeWrite;
  String? nextSave = '/notes/saved.md';
  String? folderPath = '/notes';
  List<String> folderDirectories = [];
  @override
  Future<OpenedDocument?> pick() async => null;
  @override
  Future<OpenedFolder?> folder() async => folderPath == null
      ? null
      : OpenedFolder(
          folderPath!,
          files: content.keys.toList(),
          directories: folderDirectories,
        );
  @override
  Future<OpenedDocument> read(String path) async =>
      OpenedDocument(path.split('/').last, content[path]!, path);
  @override
  Future<String?> saveAs(
    String name,
    Uint8List bytes, {
    String? dialogTitle,
  }) async {
    if (nextSave != null) content[nextSave!] = String.fromCharCodes(bytes);
    return nextSave;
  }

  @override
  Future<void> write(String path, String text, {String? expected}) async {
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
