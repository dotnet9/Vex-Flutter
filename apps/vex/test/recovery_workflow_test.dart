import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  test(
    'failed draft write leaves the document and undo history open',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final recovery = vm.recovery as MemoryRecovery;
      vm.editor.session.replace('first');
      vm.editor.session.replace('second');
      final document = vm.current;
      recovery.beforeSave = () async => throw StateError('disk unavailable');

      await expectLater(vm.closeCurrent(keepDraft: true), throwsStateError);

      expect(vm.current, same(document));
      expect(vm.documents, contains(document));
      expect(vm.recoverable, isEmpty);
      expect(vm.editor.text, 'second');
      vm.editor.session.undo();
      expect(vm.editor.text, 'first');
      recovery.beforeSave = null;
      await vm.closeCurrent(keepDraft: true);
      expect(vm.documents, isEmpty);
      expect(recovery.value.single['text'], 'first');
      expect(vm.recoverable.single['text'], 'first');
    },
  );

  test(
    'discarding old drafts preserves recovery for open dirty documents',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final recovery = vm.recovery as MemoryRecovery;
      vm.recoverable = [
        {'name': 'old.md', 'text': 'old draft'},
      ];
      vm.editor.session.replace('current draft');
      await vm.flushRecovery();

      await vm.discardDrafts();

      expect(vm.recoverable, isEmpty);
      expect(recovery.value.single['text'], 'current draft');
      expect(vm.editor.text, 'current draft');
      expect(vm.editor.session.isDirty, isTrue);
    },
  );

  test(
    'failed discard keeps the old recovery prompt available for retry',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final recovery = vm.recovery as MemoryRecovery;
      vm.recoverable = [
        {'name': 'old.md', 'text': 'old draft'},
      ];
      await vm.flushRecovery();
      recovery.beforeSave = () async => throw StateError('disk unavailable');

      await expectLater(vm.discardDrafts(), throwsStateError);

      expect(vm.recoverable.single['text'], 'old draft');
      expect(recovery.value.single['text'], 'old draft');
      recovery.beforeSave = null;
      await vm.discardDrafts();
      expect(vm.recoverable, isEmpty);
      expect(recovery.value, isEmpty);
    },
  );

  test(
    'typing during draft close keeps the latest edit open and recoverable',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final recovery = vm.recovery as MemoryRecovery;
      vm.editor.session.replace('before closing');
      final document = vm.current;
      final entered = Completer<void>(), release = Completer<void>();
      recovery.beforeSave = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };

      final closing = vm.closeCurrent(keepDraft: true);
      await entered.future;
      vm.editor.session.replace('continued typing');
      release.complete();
      await closing;

      expect(vm.current, same(document));
      expect(vm.documents, contains(document));
      expect(vm.recoverable, isEmpty);
      expect(recovery.value.single['text'], 'continued typing');
      expect(vm.editor.session.isDirty, isTrue);
    },
  );

  test('closing one draft preserves the other documents recovery', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final recovery = vm.recovery as MemoryRecovery;
    vm.editor.session.replace('first draft');
    vm.newDocument();
    vm.editor.session.replace('second draft');

    await vm.closeCurrent(keepDraft: false);

    expect(vm.editor.text, 'first draft');
    expect(recovery.value.single['text'], 'first draft');
  });
}
