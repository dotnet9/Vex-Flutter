import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class RecoveryRepository {
  Future<List<Map<String, Object?>>> load();
  Future<void> save(List<Map<String, Object?>> documents);
}

final class NativeRecoveryRepository implements RecoveryRepository {
  NativeRecoveryRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  Future<File> _file() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'recovery-v1.json'));
  }

  Future<void> _queue = Future.value();
  @override
  Future<List<Map<String, Object?>>> load() async {
    await _queue.catchError((Object _) {});
    final file = await _file();
    Object? failure;
    StackTrace? trace;
    // A flushed temporary snapshot may survive a crash between the two renames.
    for (final candidate in [
      file,
      File('${file.path}.tmp'),
      File('${file.path}.previous'),
    ]) {
      if (!await candidate.exists()) continue;
      try {
        return await _read(candidate);
      } catch (error, stack) {
        failure ??= error;
        trace ??= stack;
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, trace!);
    return [];
  }

  Future<List<Map<String, Object?>>> _read(File file) async {
    final raw = jsonDecode(await file.readAsString());
    if (raw is! List) throw const FormatException('Invalid draft snapshot');
    return raw.map((value) {
      if (value is! Map ||
          value['text'] is! String ||
          [
            'name',
            'path',
            'saved',
          ].any((key) => value[key] != null && value[key] is! String)) {
        throw const FormatException('Invalid draft document');
      }
      return Map<String, Object?>.from(value);
    }).toList();
  }

  @override
  Future<void> save(List<Map<String, Object?>> documents) {
    final snapshot = jsonEncode(documents);
    // Serialize writes so an older autosave can never replace a newer snapshot.
    final task = _queue.catchError((Object _) {}).then((_) async {
      final file = await _file();
      final pending = File('${file.path}.tmp');
      final previous = File('${file.path}.previous');
      await pending.writeAsString(snapshot, flush: true);
      var backedUp = false;
      if (await file.exists()) {
        var valid = true;
        try {
          await _read(file);
        } on FormatException {
          valid = false;
        }
        // Never replace the last readable backup with a corrupt primary file.
        if (valid) {
          await file.rename(previous.path);
          backedUp = true;
        }
      }
      try {
        await pending.rename(file.path);
      } catch (_) {
        if (backedUp) await previous.copy(file.path);
        rethrow;
      }
      // Explicitly discarded drafts must not return through a backup later.
      if (snapshot == '[]' && await previous.exists()) await previous.delete();
    });
    _queue = task;
    return task;
  }
}
