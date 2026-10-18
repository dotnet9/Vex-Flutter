import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  test(
    'large background parse cannot steal focus or discard a new draft',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      final text = '# Large\n\n${'Paragraph\n\n' * 40000}';
      files.content['/large.md'] = text;
      final opening = vm.openPath('/large.md');
      vm.newDocument();
      final draft = vm.current;
      vm.editor.session.replace('keep writing');
      await opening;
      expect(vm.current, same(draft));
      expect(vm.editor.text, 'keep writing');
      final loaded = vm.documents.singleWhere((d) => d.path == '/large.md');
      expect(loaded.editor.text, text);
      expect(loaded.editor.session.isDirty, isFalse);
      vm.switchDocument(loaded);
      expect(vm.editor.text, text);
      expect(files.readPaths, ['/large.md']);
    },
  );

  test(
    'reopening an open document keeps edits without another disk read',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content['/notes/a.md'] = 'on disk';
      await vm.openPath('/notes/a.md');
      final document = vm.current;
      vm.editor.session.replace('local edits');
      vm.newDocument();
      files.beforeRead = (_) async => throw StateError('disk unavailable');

      await vm.openPath('/notes/a.md');

      expect(vm.current, same(document));
      expect(vm.editor.text, 'local edits');
      expect(files.readPaths, ['/notes/a.md']);
      expect(vm.editor.session.isDirty, isTrue);
      vm.editor.session.undo();
      expect(vm.editor.text, 'on disk');
    },
  );

  test(
    'last requested file keeps focus when earlier reads finish later',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content.addAll({'/a.md': 'first', '/b.md': 'second'});
      final slow = Completer<void>();
      files.beforeRead = (path) async {
        if (path == '/a.md') await slow.future;
      };

      final first = vm.openPath('/a.md');
      await vm.openPath('/b.md');
      vm.editor.session.replace('second local edits');
      slow.complete();
      await first;

      expect(vm.current.path, '/b.md');
      expect(vm.editor.text, 'second local edits');
      expect(
        vm.documents.map((d) => d.path),
        unorderedEquals(['/a.md', '/b.md']),
      );
    },
  );

  test('concurrent opens of the same file create only one document', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content['/a.md'] = 'body';
    final slow = Completer<void>();
    files.beforeRead = (_) => slow.future;

    final first = vm.openPath('/a.md'), second = vm.openPath('/a.md');
    slow.complete();
    await Future.wait([first, second]);

    expect(vm.documents, hasLength(1));
    expect(vm.current.path, '/a.md');
  });

  test('a delayed file open does not steal focus from a new draft', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content['/a.md'] = 'body';
    final slow = Completer<void>();
    files.beforeRead = (_) => slow.future;
    final opening = vm.openPath('/a.md');
    vm.newDocument();
    final draft = vm.current;
    vm.editor.session.replace('keep writing');

    slow.complete();
    await opening;

    expect(vm.current, same(draft));
    expect(vm.editor.text, 'keep writing');
    expect(vm.documents, hasLength(2));
  });

  test('finishing a file read after disposal creates no document', () async {
    final vm = fakeWorkspace();
    final files = vm.files as MemoryFiles;
    files.content['/a.md'] = 'body';
    final slow = Completer<void>();
    files.beforeRead = (_) => slow.future;
    final opening = vm.openPath('/a.md');

    vm.dispose();
    slow.complete();
    await opening;

    expect(vm.documents, isEmpty);
  });
}
