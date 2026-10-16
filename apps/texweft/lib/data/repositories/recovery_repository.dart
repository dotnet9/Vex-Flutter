import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class RecoveryRepository {
  Future<List<Map<String, Object?>>> load();
  Future<void> save(List<Map<String, Object?>> documents);
}

final class NativeRecoveryRepository implements RecoveryRepository {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'recovery-v1.json'));
  }

  Future<void> _queue = Future.value();
  @override
  Future<List<Map<String, Object?>>> load() async {
    var file = await _file();
    if (!await file.exists()) file = File('${file.path}.previous');
    if (!await file.exists()) return [];
    final raw = jsonDecode(await file.readAsString()) as List;
    return raw.map((v) => Map<String, Object?>.from(v as Map)).toList();
  }

  @override
  Future<void> save(List<Map<String, Object?>> documents) {
    // Serialize writes so an older autosave can never replace a newer snapshot.
    final task = _queue.catchError((Object _) {}).then((_) async {
      final file = await _file();
      final pending = File('${file.path}.tmp');
      final previous = File('${file.path}.previous');
      await pending.writeAsString(jsonEncode(documents), flush: true);
      if (await previous.exists()) await previous.delete();
      if (await file.exists()) await file.rename(previous.path);
      try {
        await pending.rename(file.path);
      } catch (_) {
        if (await previous.exists()) await previous.rename(file.path);
        rethrow;
      }
      if (await previous.exists()) await previous.delete();
    });
    _queue = task;
    return task;
  }
}
