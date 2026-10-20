import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_outline.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('selecting an unsaved file in the phone list closes navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    vm.newDocument();
    vm.editor.session.replace('First draft');
    final first = vm.current;
    vm.newDocument();
    vm.setFileListMode(FileListMode.list);
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('document-sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
      isTrue,
    );
    await tester.tap(find.byKey(ValueKey('sidebar-file-${first.id}')));
    await tester.pumpAndSettle();
    expect(vm.current, same(first));
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets('document keeps controls and words in a fixed bottom bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    vm.editor.session.replace('# 想法\n\nHello world 你好');
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    expect(find.text('6 字词'), findsOneWidget);
    final surface = tester.getRect(
      find.byKey(const ValueKey('document-surface')),
    );
    expect(surface.bottom, 800);
    final count = tester.getRect(
      find.byKey(const ValueKey('document-word-count')),
    );
    expect(count.right, lessThan(surface.right));
    expect(count.bottom, lessThan(surface.bottom));
    expect(find.byKey(const ValueKey('document-source-toggle')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('workspace-view-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('layout-source')));
    await tester.pumpAndSettle();
    expect(vm.layout, WorkspaceLayout.source);
    await tester.tap(find.byKey(const ValueKey('document-sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(vm.sidebar, isFalse);
    vm.updateAppearance(wordCountVisible: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('document-word-count')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets(
    'file excerpts read bounded previews; outline search is independent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      final memory = vm.files as MemoryFiles;
      vm.showStructure(true);
      memory.content.addAll({
        '/notes/first.md': '# First\n\n## Apple\n\nVisible **summary**',
        '/notes/topic/second.md': '# Second\n\nA short excerpt',
      });
      await vm.openPath('/notes/first.md');
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sidebar-file-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sidebar-view-toggle')));
      await tester.pumpAndSettle();
      expect(vm.fileListMode, FileListMode.list);
      expect(find.text('A short excerpt', findRichText: true), findsNothing);
      expect(memory.previewPaths, ['/notes/topic/second.md']);
      expect(memory.readPaths, ['/notes/first.md']);
      final outline = find.byType(WorkspaceOutline);
      await tester.enterText(
        find.byKey(const ValueKey('sidebar-search')),
        'first',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('outline-search')),
        'Apple',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: outline,
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.data == 'Apple',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sidebar-footer')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('outline-search')),
        'absent',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: outline, matching: find.text('Apple')),
        findsNothing,
      );
      expect(vm.filter, 'first');
      expect(find.byKey(const ValueKey('sidebar-footer')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
