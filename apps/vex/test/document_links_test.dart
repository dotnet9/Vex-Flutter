import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_links.dart';

import 'support/fakes.dart';

void main() {
  final root = p.absolute('vex-link-test');
  final first = p.join(root, 'index.md');
  final second = p.join(root, '章节', '第二篇 笔记.md');
  const target = '# 第二篇\n\n## 目标\n\n保留内容';
  final href = '${Uri(path: '章节/第二篇 笔记.md')}#${Uri.encodeComponent('目标')}';

  test(
    'relative Unicode file links open inside Vex and reveal their heading',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content.addAll({first: '# Index', second: target});
      await vm.openPath(first);
      final source = vm.current;
      vm.setLayout(WorkspaceLayout.read);

      await openWorkspaceLink(vm, href);

      expect(vm.current.path, second);
      expect(vm.selectedHeading?.title, '目标');
      expect(vm.layout, WorkspaceLayout.read);
      expect(vm.editor.session.isDirty, isFalse);
      expect(source.editor.text, '# Index');
      expect(vm.folder?.path, root);
      expect(files.readPaths, [first, second]);
    },
  );

  test(
    'parent and file URI links reuse open documents without losing edits',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content.addAll({first: '# Index', second: target});
      await vm.openPath(first);
      final index = vm.current;
      vm.editor.session.replace('# Local edits');
      await vm.openPath(second);

      await openWorkspaceLink(vm, '../index.md');
      expect(vm.current, same(index));
      expect(vm.editor.text, '# Local edits');
      expect(vm.editor.session.isDirty, isTrue);
      await openWorkspaceLink(vm, '${p.toUri(second)}#目标');
      expect(vm.current.path, second);
      expect(vm.selectedHeading?.title, '目标');
      expect(vm.documents, hasLength(2));
      expect(files.readPaths, [first, second]);
    },
  );

  test(
    'unsaved documents never resolve links against the process directory',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      vm.editor.session.replace('[文档](index.md)');
      final source = vm.current;

      await openWorkspaceLink(vm, 'index.md');

      expect(vm.current, same(source));
      expect(vm.status, vm.strings.documentLinkNeedsFile);
      expect(files.readPaths, isEmpty);
      expect(vm.editor.text, '[文档](index.md)');
    },
  );

  test(
    'local links cannot execute files or silently access network shares',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content[first] = '# Index';
      await vm.openPath(first);
      for (final link in [
        'javascript:alert(1)',
        'data:text/plain,hello',
        'app.exe',
        'script.bat',
        'file://server/share/note.md',
        'file://localhost/share/note.md',
        'file:////server/share/note.md',
        '//server/share/note.md',
        'index.md?command=anything',
        'invalid%FF.md',
      ]) {
        await openWorkspaceLink(vm, link);
        expect(vm.current.path, first, reason: link);
        expect(files.readPaths, [first], reason: link);
      }
    },
  );

  test(
    'unavailable documents show an ordinary-user message and retain the source',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content[first] = '# Index';
      await vm.openPath(first);
      final source = vm.current;
      files.beforeRead = (path) async =>
          throw FileSystemException('denied', path);

      await openWorkspaceLink(vm, 'missing.md');

      expect(vm.current, same(source));
      expect(vm.status, vm.strings.documentLinkUnavailable);
      expect(vm.documents, [source]);
      expect(vm.editor.text, '# Index');
    },
  );

  test(
    'late linked-file completion never redirects a newer draft to its anchor',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content.addAll({first: '# Index', second: target});
      await vm.openPath(first);
      final started = Completer<void>(), release = Completer<void>();
      files.beforeRead = (_) async {
        started.complete();
        await release.future;
      };
      final opening = openWorkspaceLink(vm, href);
      await started.future;
      vm.newDocument();
      final draft = vm.current;
      vm.editor.session.replace('# Draft\n\nKeep writing');
      vm.editor.select(vm.editor.text.length);
      final selection = vm.editor.selection;
      release.complete();
      await opening;

      expect(vm.current, same(draft));
      expect(vm.editor.selection, selection);
      expect(vm.selectedHeading, isNull);
      expect(vm.documents.any((d) => d.path == second), isTrue);
    },
  );

  test(
    'late linked-file failure never replaces a newer document notice',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content[first] = '# Index';
      await vm.openPath(first);
      final started = Completer<void>(), release = Completer<void>();
      files.beforeRead = (path) async {
        started.complete();
        await release.future;
        throw FileSystemException('denied', path);
      };
      final opening = openWorkspaceLink(vm, 'missing.md');
      await started.future;
      vm.newDocument();
      vm.followAnchor('#current-notice');
      final notice = vm.status;
      release.complete();
      await opening;

      expect(vm.status, notice);
      expect(vm.current.path, isNull);
    },
  );

  for (final extension in ['MD', 'markdown', 'txt']) {
    test('linked .$extension documents use the supported file types', () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      final path = p.join(root, 'note.$extension');
      files.content.addAll({first: '# Index', path: '# Note'});
      await vm.openPath(first);
      await openWorkspaceLink(vm, 'note.$extension');
      expect(vm.current.path, path);
    });
  }

  for (final width in [1280.0, 390.0]) {
    testWidgets('reading a linked document and heading at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      final files = vm.files as MemoryFiles;
      files.content.addAll({first: '# Index\n\n[下一篇]($href)', second: target});
      await vm.openPath(first);
      vm.setLayout(WorkspaceLayout.read);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一篇', findRichText: true));
      await tester.pumpAndSettle();

      expect(vm.current.path, second);
      expect(vm.selectedHeading?.title, '目标');
      expect(find.text('保留内容', findRichText: true), findsOneWidget);
      expect(vm.layout, WorkspaceLayout.read);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
  }
}
