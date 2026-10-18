import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/ui/workspace/workspace_sidebar.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('opening a file shows its siblings in a nested directory tree', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    final files = vm.files as MemoryFiles;
    files.content.addAll({
      '/notes/first.md': '# First',
      '/notes/topic/child.md': '# Child',
    });
    await vm.openPath('/notes/first.md');
    vm.editor.select(0);
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    final sidebar = find.byType(WorkspaceSidebar);
    final child = find.descendant(of: sidebar, matching: find.text('child.md'));
    expect(
      find.descendant(of: sidebar, matching: find.text('first.md')),
      findsOneWidget,
    );
    expect(child, findsOneWidget);
    expect(
      tester.getTopLeft(child).dx,
      greaterThan(tester.getTopLeft(find.text('topic')).dx),
    );
    await tester.tap(find.text('topic'));
    await tester.pumpAndSettle();
    expect(child, findsNothing);
    expect(files.readPaths, ['/notes/first.md']);
    files.content['/other/other.md'] = '# Other';
    await vm.openPath('/other/other.md');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: sidebar, matching: find.text('first.md')),
    );
    await tester.pumpAndSettle();
    expect(vm.folder?.path, '/notes');
    expect(child, findsOneWidget);
    expect(files.readPaths, ['/notes/first.md', '/other/other.md']);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets(
    'directory search opens one document and restores collapsed folders',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      final files = vm.files as MemoryFiles;
      files.content.addAll({
        '/notes/文章.md': '# 文章',
        '/notes/专题/子目录/数学.md': '# 数学',
        '/notes/专题/流程.md': '# 流程',
      });
      files.folderDirectories = ['/notes/专题', '/notes/专题/子目录', '/notes/空目录'];
      await tester.pumpWidget(VexApp(viewModel: vm));
      await vm.openFolder();
      await tester.pumpAndSettle();
      final nested = find.descendant(
        of: find.byType(WorkspaceSidebar),
        matching: find.text('数学.md'),
      );
      expect(find.text('空目录'), findsOneWidget);
      expect(nested, findsOneWidget);
      await tester.tap(find.text('专题'));
      await tester.pumpAndSettle();
      expect(nested, findsNothing);
      final search = find.byKey(const ValueKey('sidebar-search'));
      await tester.enterText(search, '数学');
      await tester.pumpAndSettle();
      expect(nested, findsOneWidget);
      expect(find.text('流程.md'), findsNothing);
      await tester.tap(nested);
      await tester.pumpAndSettle();
      expect(vm.current.path, '/notes/专题/子目录/数学.md');
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(vm.filter, isEmpty);
      expect(nested, findsNothing);
      await tester.tap(find.text('专题'));
      await tester.pumpAndSettle();
      expect(nested, findsOneWidget);
      expect(vm.documents, hasLength(1));
      await tester.tap(nested);
      await tester.pumpAndSettle();
      expect(vm.documents, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
