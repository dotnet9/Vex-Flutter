import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/repositories/window_recovery_repository.dart';

void main() {
  late Directory directory;
  final repositories = <WindowRecoveryRepository>[];
  List<Map<String, Object?>> draft(String text) => [
    {'name': 'draft.md', 'text': text},
  ];
  WindowRecoveryRepository repository() {
    final result = WindowRecoveryRepository(directory: () async => directory);
    repositories.add(result);
    return result;
  }

  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'vex-window-recovery-',
    ),
  );
  tearDown(() async {
    for (final repository in repositories) {
      await repository.close();
    }
    repositories.clear();
    await directory.delete(recursive: true);
  });

  test(
    'one session serializes load and saves without creating extra directories',
    () async {
      final store = repository();
      final first = store.load();
      final saving = store.save(draft('latest'));
      expect(await first, isEmpty);
      await saving;
      expect(await store.load(), draft('latest'));
      expect(
        await Directory('${directory.path}/recovery-sessions').list().length,
        1,
      );
      await store.close();
      await expectLater(store.save([]), throwsStateError);
    },
  );

  test(
    'abandoned drafts survive closing before adoption and recover exactly once',
    () async {
      final original = repository();
      await original.save(draft('unfinished'));
      await original.close();
      final first = repository();
      expect(await first.load(), draft('unfinished'));
      expect(await first.load(), draft('unfinished'));
      await first.close();
      final retry = repository();
      expect(await retry.load(), draft('unfinished'));
      await retry.save(draft('unfinished'));
      await retry.close();
      final last = repository();
      expect(await last.load(), draft('unfinished'));
      await last.save([]);
      await last.close();
      expect(await repository().load(), isEmpty);
    },
  );

  test(
    'failed new snapshot never marks an abandoned session as adopted',
    () async {
      final original = repository();
      await original.save(draft('keep me'));
      await original.close();
      final next = repository();
      expect(await next.load(), draft('keep me'));
      final root = Directory('${directory.path}/recovery-sessions');
      final own =
          (await root.list().where((entry) => entry is Directory).toList())
              .cast<Directory>()
              .singleWhere(
                (dir) => !File('${dir.path}/recovery-v1.json').existsSync(),
              );
      await Directory('${own.path}/recovery-v1.json.tmp').create();
      await expectLater(
        next.save(draft('keep me')),
        throwsA(isA<FileSystemException>()),
      );
      await next.close();
      await own.delete(recursive: true);
      expect(await repository().load(), draft('keep me'));
    },
  );

  test('a real second process keeps active drafts out of recovery', () async {
    var root = Directory.current;
    while (!File('${root.path}/.dart_tool/package_config.json').existsSync()) {
      if (root.parent.path == root.path) {
        throw StateError('Package configuration not found');
      }
      root = root.parent;
    }
    final config = File('${root.path}/.dart_tool/package_config.json');
    final packages =
        (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
    final flutter = packages.cast<Map>().singleWhere(
      (entry) => entry['name'] == 'flutter',
    );
    final flutterRoot = Directory.fromUri(
      config.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    final dart =
        '${flutterRoot.path}/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
    final child = await Process.start(dart, [
      'test/support/recovery_lock.dart',
      directory.path,
    ]);
    addTearDown(() => child.kill());
    final ready = child.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    expect(await ready.timeout(const Duration(seconds: 15)), 'ready');
    final active = repository();
    expect(await active.load(), isEmpty);
    await active.save(draft('my own window'));
    expect(
      jsonDecode(
        await File(
          '${directory.path}/recovery-sessions/active/recovery-v1.json',
        ).readAsString(),
      ),
      draft('another window').map((d) => {...d, 'name': 'active.md'}),
    );
    child.stdin.writeln('close');
    await child.stdin.close();
    expect(await child.exitCode, 0);
    await active.close();
    final recovered = await repository().load();
    expect(
      recovered.map((d) => d['text']),
      unorderedEquals(['another window', 'my own window']),
    );
  });
}
