import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/ui/workspace/workspace_menu.dart';
import 'package:texweft_editor/texweft_editor.dart';

import 'support/fakes.dart';

const sample = '| Name | Value |\n| --- | --- |\n| One | Two |\n';

void main() {
  test('table submenu disables unavailable actions and respects readonly', () {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final empty = workspaceTableEntries(vm.strings, null);
    expect(empty.where((item) => item.enabled).map((item) => item.id), [
      'format:table',
    ]);
    vm.editor.session.replace(sample);
    final target = vm.editor.tableTarget(offset: 0)!;
    final entries = workspaceTableEntries(vm.strings, target);
    expect(
      entries.firstWhere((item) => item.id == 'table:deleteRow').enabled,
      isFalse,
    );
    expect(
      entries.firstWhere((item) => item.id == 'table:rowBelow').enabled,
      isTrue,
    );
    final read = workspaceTableEntries(vm.strings, target, readOnly: true);
    expect(read.where((item) => item.enabled).map((item) => item.id), [
      'table:copy',
    ]);
  });

  testWidgets('table cell secondary click inserts a row and shares undo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    vm.editor.session.replace(sample);
    await tester.pumpWidget(TexweftApp(viewModel: vm));
    await tester.pumpAndSettle();
    final cell = find.byKey(const ValueKey('table-cell-1-1'));
    await tester.tap(cell, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-table:rowBelow')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu-table:rowBelow')));
    await tester.pumpAndSettle();
    expect(vm.editor.tableTarget()!.table.rows, hasLength(3));
    vm.editor.session.undo();
    await tester.pumpAndSettle();
    expect(vm.editor.text, sample);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'phone table context is a fixed-header sheet and stale commands are rejected',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.editor.session.replace(sample);
      await tester.pumpWidget(TexweftApp(viewModel: vm));
      await tester.pumpAndSettle();
      final cell = find.byKey(const ValueKey('table-cell-1-0'));
      await tester.tap(cell);
      await tester.pumpAndSettle();
      await tester.longPressAt(tester.getTopLeft(cell) + const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('touch-workspace-menu')),
        findsOneWidget,
      );
      final header = tester.getTopLeft(
        find.byKey(const ValueKey('touch-menu-heading')),
      );
      vm.editor.session.replace('$sample\nNew content');
      await tester.pumpAndSettle();
      final deletion = find.byKey(const ValueKey('touch-menu-table:delete'));
      await tester.scrollUntilVisible(
        deletion,
        180,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('touch-workspace-menu')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('touch-menu-heading'))),
        header,
      );
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      expect(vm.editor.text, '$sample\nNew content');
      expect(find.textContaining(vm.strings.documentChanged), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
