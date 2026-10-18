import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_dialogs.dart';
import 'package:vex/ui/workspace/workspace_sidebar.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  for (final size in [
    const Size(1280, 800),
    const Size(900, 700),
    const Size(390, 844),
  ]) {
    testWidgets('find and replace belong above the editor at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.showFind(replace: true);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byKey(const ValueKey('editor-findbar')));
      final editor = tester.getRect(find.byType(WorkspacePanes));
      expect(bar.left, editor.left);
      expect(bar.right, editor.right);
      expect(bar.bottom, lessThan(editor.top));
      if (size.width >= 700) {
        final sidebar = tester.getRect(find.byType(WorkspaceSidebar));
        expect(bar.left, greaterThan(sidebar.right));
        expect(sidebar.top, bar.top);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
  }
  testWidgets('source scroll position survives switching layouts', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    vm.editor.session.replace(List.generate(400, (i) => 'Line $i').join('\n'));
    vm.setLayout(WorkspaceLayout.source);
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    Finder sourceScrollable() => find.descendant(
      of: find.byType(MarkdownSourceEditor),
      matching: find.byType(Scrollable),
    );
    final first = tester.state<ScrollableState>(sourceScrollable());
    first.position.jumpTo(1600);
    await tester.pumpAndSettle();
    vm.setLayout(WorkspaceLayout.read);
    await tester.pumpAndSettle();
    vm.setLayout(WorkspaceLayout.source);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(sourceScrollable()).position.pixels,
      closeTo(1600, .1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
  testWidgets(
    'reader lazily renders long documents and locates an offscreen heading',
    (tester) async {
      final vm = fakeWorkspace();
      vm.editor.session.replace(
        List.generate(500, (i) => '## Chapter $i\n\nParagraph $i\n').join('\n'),
      );
      vm.editor.session.markSaved();
      vm.setLayout(WorkspaceLayout.read);
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownReader).evaluate().length, lessThan(30));
      expect(find.text('Chapter 490'), findsNothing);
      final source = vm.editor.session.text;
      vm.selectHeading(vm.editor.document.headings[490]);
      await tester.pumpAndSettle();
      expect(find.text('Chapter 490').hitTestable(), findsOneWidget);
      expect(vm.editor.session.text, source);
      expect(vm.editor.session.isDirty, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
  testWidgets(
    'all eight desktop layouts render without overflow in both themes',
    (tester) async {
      final vm = fakeWorkspace();
      await tester.binding.setSurfaceSize(const Size(980, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: mode);
        await tester.pumpAndSettle();
        for (final layout in WorkspaceLayout.values) {
          vm.setLayout(layout);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${mode.name}/${layout.name}',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
  testWidgets('phone navigation and appearance dialog fit a narrow display', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    expect(find.text('写作'), findsOneWidget);
    await tester.tap(find.text('导图'));
    await tester.pumpAndSettle();
    expect(vm.layout, WorkspaceLayout.map);
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(Scaffold).first);
    final dialog = showAppearance(context, vm);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await dialog;
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
