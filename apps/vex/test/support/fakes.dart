import 'dart:typed_data';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:vex/data/repositories/recovery_repository.dart';
import 'package:vex/data/repositories/credential_repository.dart';
import 'package:vex/data/repositories/settings_repository.dart';
import 'package:vex/data/services/file_service.dart';
import 'package:vex/data/services/document_codec.dart';
import 'package:vex/domain/file_preferences.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

final class MemoryCredentials implements CredentialRepository {
  String? token;
  @override
  Future<String?> readMcpToken() async => token;
  @override
  Future<void> writeMcpToken(String token) async {
    this.token = token;
  }
}

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
  Future<void> Function(String path)? beforeReadFolder;
  final readPaths = <String>[];
  final previewPaths = <String>[];
  final readFolderPaths = <String>[];
  OpenedDocument? picked;
  String? nextSave = '/notes/saved.md';
  String? folderPath = '/notes';
  List<String> folderDirectories = [];
  Uint8List? lastSavedBytes;
  String? lastSaveName, lastInitialDirectory;
  @override
  Future<String> readPreview(String path) async {
    previewPaths.add(path);
    final text = content[path]!;
    return text.substring(0, text.length.clamp(0, 8192));
  }

  @override
  Future<OpenedDocument?> pick() async => picked;
  @override
  Future<OpenedFolder?> folder({
    Set<String> excludedDirectories = defaultExcludedDirectories,
    void Function(OpenedFolder)? onProgress,
    bool Function()? cancelled,
  }) async => folderPath == null
      ? null
      : readFolder(
          folderPath!,
          excludedDirectories: excludedDirectories,
          onProgress: onProgress,
          cancelled: cancelled,
        );
  @override
  Future<OpenedFolder> readFolder(
    String path, {
    Set<String> excludedDirectories = defaultExcludedDirectories,
    void Function(OpenedFolder)? onProgress,
    bool Function()? cancelled,
  }) async {
    readFolderPaths.add(path);
    await beforeReadFolder?.call(path);
    return OpenedFolder(
      path,
      files: content.keys.where((file) => p.isWithin(path, file)).toList(),
      directories: folderDirectories
          .where((directory) => p.isWithin(path, directory))
          .toList(),
    );
  }

  @override
  Future<OpenedDocument> read(String path) async {
    readPaths.add(path);
    if (beforeRead != null) await beforeRead!(path);
    final entry = content.entries.firstWhere(
      (entry) =>
          p.equals(entry.key, path) ||
          (File(entry.key).existsSync() &&
              p.equals(File(entry.key).resolveSymbolicLinksSync(), path)),
    );
    return OpenedDocument(p.basename(entry.key), entry.value, entry.key);
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
  credentials: MemoryCredentials(),
  files: MemoryFiles(),
  settings: MemorySettings(),
  recovery: MemoryRecovery(),
);
