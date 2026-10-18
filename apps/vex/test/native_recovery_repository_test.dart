import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/repositories/recovery_repository.dart';

void main() {
  late Directory directory;
  late NativeRecoveryRepository repository;
  late File primary, pending, previous;
  List<Map<String, Object?>> draft(String text) => [
    {'name': 'draft.md', 'text': text},
  ];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vex-recovery-test-');
    repository = NativeRecoveryRepository(directory: () async => directory);
    primary = File('${directory.path}/recovery-v1.json');
    pending = File('${primary.path}.tmp');
    previous = File('${primary.path}.previous');
  });
  tearDown(() => directory.delete(recursive: true));

  test('keeps a readable previous snapshot after a successful save', () async {
    await repository.save(draft('first'));
    await repository.save(draft('second'));
    expect(await repository.load(), draft('second'));
    expect(jsonDecode(await previous.readAsString()), draft('first'));
    await primary.writeAsString('{truncated');
    expect(await repository.load(), draft('first'));
    await repository.save(draft('third'));
    expect(await repository.load(), draft('third'));
    expect(jsonDecode(await previous.readAsString()), draft('first'));
  });

  test(
    'recovers an interrupted rename from the flushed temporary file',
    () async {
      await previous.writeAsString(jsonEncode(draft('old')));
      await pending.writeAsString(jsonEncode(draft('latest')));
      expect(await repository.load(), draft('latest'));
      await pending.writeAsString('[{"text":');
      expect(await repository.load(), draft('old'));
    },
  );

  test(
    'prefers a valid committed primary over an abandoned temporary',
    () async {
      await repository.save(draft('committed'));
      await pending.writeAsString(jsonEncode(draft('uncommitted')));
      expect(await repository.load(), draft('committed'));
    },
  );

  test(
    'rejects invalid document fields and does not silently lose drafts',
    () async {
      expect(await repository.load(), isEmpty);
      await primary.writeAsString('[{"text":"draft","path":42}]');
      await expectLater(repository.load(), throwsFormatException);
      await previous.writeAsString(jsonEncode(draft('readable')));
      expect(await repository.load(), draft('readable'));
    },
  );

  test(
    'queued saves snapshot input at request time and loads wait for them',
    () async {
      final first = draft('first');
      final writing = repository.save(first);
      first.single['text'] = 'mutated after requesting save';
      expect(await repository.load(), draft('first'));
      await writing;
      final second = repository.save(draft('second'));
      final third = repository.save(draft('third'));
      expect(await repository.load(), draft('third'));
      await Future.wait([second, third]);
    },
  );

  test('discarding drafts also removes the backup recovery path', () async {
    await repository.save(draft('private draft'));
    await repository.save([]);
    expect(await previous.exists(), isFalse);
    expect(await pending.exists(), isFalse);
    expect(await repository.load(), isEmpty);
    await primary.delete();
    expect(await repository.load(), isEmpty);
  });
}
