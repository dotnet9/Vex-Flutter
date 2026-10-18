import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vex/data/services/file_service.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

void main() {
  test(
    'opening one file enumerates its parent without reading siblings',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content.addAll({
        '/notes/a.md': '# First',
        '/notes/nested/b.md': '# Second',
        '/other/c.md': '# Outside',
      });
      files.folderDirectories = ['/notes/nested', '/notes/empty'];

      await vm.openPath('/notes/a.md');

      expect(vm.folder?.path, '/notes');
      expect(vm.folder?.files, ['/notes/a.md', '/notes/nested/b.md']);
      expect(vm.folder?.directories, files.folderDirectories);
      expect(files.readPaths, ['/notes/a.md']);
      await vm.openPath('/notes/nested/b.md');
      expect(vm.folder?.path, '/notes');
      expect(files.readFolderPaths, ['/notes']);
      expect(files.readPaths, ['/notes/a.md', '/notes/nested/b.md']);
    },
  );

  test(
    'desktop picker loads a tree but a mobile cache copy does not',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.picked = const OpenedDocument(
        'first.md',
        '# First',
        '/notes/first.md',
      );
      await vm.open();
      expect(vm.folder?.path, '/notes');
      files.picked = const OpenedDocument('copy.md', '# Copy', null);
      await vm.open();
      expect(vm.current.name, 'copy.md');
      expect(files.readFolderPaths, ['/notes']);
    },
  );

  test('document is ready before the directory scan completes', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content['/notes/a.md'] = '# Ready';
    final scanning = Completer<void>(), release = Completer<void>();
    files.beforeReadFolder = (_) {
      scanning.complete();
      return release.future;
    };
    final opening = vm.openPath('/notes/a.md');
    await scanning.future;
    expect(vm.current.path, '/notes/a.md');
    expect(vm.editor.document.headings.single.title, 'Ready');
    vm.newDocument();
    release.complete();
    await opening;
    expect(vm.current.path, isNull);
    expect(vm.folder, isNull);
  });

  test('older scans cannot replace the latest file directory', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content.addAll({'/first/a.md': 'A', '/second/b.md': 'B'});
    final scanning = Completer<void>(), release = Completer<void>();
    files.beforeReadFolder = (path) async {
      if (path == '/first') {
        scanning.complete();
        await release.future;
      }
    };
    final first = vm.openPath('/first/a.md');
    await scanning.future;
    await vm.openPath('/second/b.md');
    release.complete();
    await first;
    expect(vm.folder?.path, '/second');
    expect(vm.current.path, '/second/b.md');
  });

  test('explicit folder selection supersedes an automatic scan', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content['/first/a.md'] = 'A';
    final scanning = Completer<void>(), release = Completer<void>();
    files.beforeReadFolder = (path) async {
      if (path == '/first') {
        scanning.complete();
        await release.future;
      }
    };
    final opening = vm.openPath('/first/a.md');
    await scanning.future;
    files.folderPath = '/chosen';
    await vm.openFolder();
    release.complete();
    await opening;
    expect(vm.folder?.path, '/chosen');
    expect(vm.current.path, '/first/a.md');
  });

  test('inaccessible parent does not prevent reading the file', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content['/notes/a.md'] = 'A';
    files.beforeReadFolder = (path) async {
      throw FileSystemException('Access denied', path);
    };
    await vm.openPath('/notes/a.md');
    expect(vm.current.path, '/notes/a.md');
    expect(vm.editor.text, 'A');
    expect(vm.folder, isNull);
  });

  test('finishing a directory scan after disposal has no effect', () async {
    final vm = fakeWorkspace();
    final files = vm.files as MemoryFiles;
    files.content['/notes/a.md'] = 'A';
    final scanning = Completer<void>(), release = Completer<void>();
    files.beforeReadFolder = (_) {
      scanning.complete();
      return release.future;
    };
    final opening = vm.openPath('/notes/a.md');
    await scanning.future;
    vm.dispose();
    release.complete();
    await opening;
    expect(vm.folder, isNull);
  });

  test('native file open discovers real nested Markdown paths', () async {
    final directory = await Directory.systemTemp.createTemp('vex-open-tree-');
    addTearDown(() => directory.delete(recursive: true));
    final nested = await Directory(p.join(directory.path, 'nested')).create();
    final first = await File(p.join(directory.path, 'a.md'))
        .writeAsString('# A');
    final second = await File(p.join(nested.path, 'b.md')).writeAsString('# B');
    final vm = WorkspaceViewModel(
      files: NativeDocumentFileService(),
      settings: MemorySettings(),
      recovery: MemoryRecovery(),
    );
    addTearDown(vm.dispose);
    await vm.openPath(first.path);
    expect(vm.current.path, first.path);
    expect(vm.folder?.path, directory.path);
    expect(
      vm.folder!.files.map(p.normalize),
      containsAll([first.path, second.path].map(p.normalize)),
    );
  });

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
