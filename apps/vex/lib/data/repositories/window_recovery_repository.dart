import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'recovery_repository.dart';

/// Each process owns a locked session. Only abandoned sessions are recovered.
final class WindowRecoveryRepository implements RecoveryRepository {
  WindowRecoveryRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  final _claimed = <({Directory directory, RandomAccessFile lock})>[];
  NativeRecoveryRepository? _store;
  Directory? _own;
  RandomAccessFile? _lock;
  Future<void> _pending = Future.value();
  Future<Directory>? _initialization;
  Future<void>? _closing;
  bool _scanned = false;
  final _recovered = <Map<String, Object?>>[];

  Future<Directory> _initialize() => _initialization ??= _createSession();

  Future<Directory> _createSession() async {
    final root = Directory(
      p.join((await _directory()).path, 'recovery-sessions'),
    );
    await root.create(recursive: true);
    final own = await root.createTemp('$pid-');
    _lock = await File(p.join(own.path, 'session.lock'))
        .open(mode: FileMode.append);
    await _lock!.lock(FileLock.exclusive);
    _store = NativeRecoveryRepository(directory: () async => own);
    _own = own;
    return root;
  }

  @override
  Future<List<Map<String, Object?>>> load() => _enqueue(() async {
    final root = await _initialize();
    if (_scanned) return [..._recovered, ...await _store!.load()];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory || entry.path == _own!.path) continue;
      RandomAccessFile? lock;
      try {
        lock = await File(p.join(entry.path, 'session.lock'))
            .open(mode: FileMode.append);
        await lock.lock(FileLock.exclusive);
      } on FileSystemException {
        await lock?.close();
        continue;
      }
      if (await File(p.join(entry.path, 'adopted')).exists()) {
        await lock.close();
        continue;
      }
      // Keep the claim until a durable combined snapshot has been written.
      _claimed.add((directory: entry, lock: lock));
      final store = NativeRecoveryRepository(directory: () async => entry);
      _recovered.addAll(await store.load());
    }
    _scanned = true;
    return [..._recovered, ...await _store!.load()];
  });

  @override
  Future<void> save(List<Map<String, Object?>> documents) {
    final snapshot = [
      for (final doc in documents) Map<String, Object?>.of(doc),
    ];
    return _enqueue(() async {
      await _initialize();
      await _store!.save(snapshot);
      _recovered.clear();
      for (final claim in List.of(_claimed)) {
        await File(p.join(claim.directory.path, 'adopted'))
            .writeAsString(_own!.path, flush: true);
        await claim.lock.close();
        try {
          await claim.directory.delete(recursive: true);
        } on FileSystemException {
          // The durable adoption marker prevents duplicate recovery if cleanup
          // is temporarily blocked by an indexer or another process.
        }
        _claimed.remove(claim);
      }
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (_closing != null) {
      return Future.error(StateError('Recovery session is closed'));
    }
    final task = _pending.catchError((Object _) {}).then((_) => operation());
    _pending = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<void> close() => _closing ??= _release();

  Future<void> _release() async {
    await _pending.catchError((Object _) {});
    for (final claim in _claimed) {
      await claim.lock.close();
    }
    _claimed.clear();
    await _lock?.close();
    _lock = null;
  }
}
