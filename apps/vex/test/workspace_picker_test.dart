import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  for (final size in [const Size(1280, 800), const Size(390, 844)]) {
    testWidgets('pickers update the document without a modal barrier at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      vm.editor.session.replace('# 排版检查\n\n用自己的文章验证排版切换。');
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      // Navigator's home route has its own transparent barrier behind the page.
      // Opening a picker must not add another barrier above the document.
      final routeBarriers = find.byType(ModalBarrier).evaluate().toList();
      final original = vm.editor.text;
      if (size.width < 700) {
        expect(find.byTooltip('工作区布局'), findsNothing);
        vm.setLayout(WorkspaceLayout.read);
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.byTooltip('工作区布局'));
        await tester.pumpAndSettle();
        expect(find.byType(ModalBarrier).evaluate().toList(), routeBarriers);
        await tester.tap(find.byKey(const ValueKey('layout-read')));
        await tester.pumpAndSettle();
        expect(vm.layout, WorkspaceLayout.read);
        expect(find.byKey(const ValueKey('layout-read')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('workspace-view-selector')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('layout-read')), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Markdown 排版'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('layout-read')), findsNothing);
      expect(find.byKey(const ValueKey('typography-picker')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('typography-picker')), findsNothing);
      await tester.tap(find.byTooltip('Markdown 排版'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('typography-book')));
      await tester.pumpAndSettle();
      expect(vm.typography, MarkdownTypography.book);
      expect(find.byKey(const ValueKey('typography-picker')), findsOneWidget);
      expect(find.byType(ModalBarrier).evaluate().toList(), routeBarriers);
      expect(
        tester
            .widget<MarkdownReader>(find.byType(MarkdownReader).last)
            .typography,
        MarkdownTypography.book,
      );
      vm.updateAppearance(mode: ThemeMode.dark);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('typography-technical')));
      await tester.pumpAndSettle();
      expect(vm.typography, MarkdownTypography.technical);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('typography-picker')), findsNothing);
      await tester.tap(find.byTooltip('Markdown 排版'));
      await tester.pumpAndSettle();
      // One outside click both dismisses the panel and performs the action.
      await tester.tap(find.byKey(const ValueKey('document-sidebar-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('typography-picker')), findsNothing);
      if (size.width < 700) {
        expect(find.byType(Drawer), findsOneWidget);
      } else {
        expect(vm.sidebar, isFalse);
      }
      expect(vm.editor.text, original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
  }

  testWidgets(
    'table dialog validates dimensions, cancels safely and inserts one undoable table',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      const original = '前文\n\n后文';
      vm.editor.session.replace(original);
      vm.editor.select(4);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final toolbar = find.byTooltip('表格');
      await tester.ensureVisible(toolbar);
      await tester.tap(toolbar);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(vm.editor.text, original);
      await tester.tap(toolbar);
      await tester.pumpAndSettle();
      final rows = find.byKey(const ValueKey('table-rows'));
      final columns = find.byKey(const ValueKey('table-columns'));
      await tester.enterText(rows, '0');
      await tester.enterText(columns, '21');
      await tester.tap(find.text('插入'));
      await tester.pumpAndSettle();
      expect(find.text('请输入 1–100 之间的整数'), findsOneWidget);
      expect(find.text('请输入 1–20 之间的整数'), findsOneWidget);
      expect(vm.editor.text, original);
      await tester.enterText(rows, '4');
      await tester.enterText(columns, '3');
      await tester.tap(find.text('插入'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('table-rows')), findsNothing);
      final table = vm.editor.document.blocks.firstWhere(
        (block) => block.kind.name == 'table',
      );
      expect(table.range.slice(vm.editor.text).trim().split('\n').length, 5);
      expect(vm.editor.text, contains('| 标题1 | 标题2 | 标题3 |'));
      expect(vm.editor.text, startsWith('前文\n\n'));
      expect(vm.editor.text, endsWith('\n\n后文'));
      vm.editor.session.undo();
      expect(vm.editor.text, original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
