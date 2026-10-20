import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';

import 'support/fakes.dart';

void main() {
  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    testWidgets('writing margins and bounded reading lines fit $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.editor.session.replace('# A title\n\nReadable body text.');
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: theme, fontSize: 24);
        for (final layout in [WorkspaceLayout.instant, WorkspaceLayout.read]) {
          vm.setLayout(layout);
          await tester.pumpAndSettle();
          final list = tester.widget<SuperListView>(
            find.descendant(
              of: find.byType(WorkspacePanes),
              matching: find.byType(SuperListView),
            ),
          );
          final padding = list.padding!.resolve(TextDirection.ltr);
          final base = size.width < 700 ? 25.0 : 44.0;
          if (layout == WorkspaceLayout.read) {
            final listWidth = tester.getSize(find.byWidget(list)).width;
            final readingWidth = listWidth - padding.horizontal;
            expect(padding.left, greaterThanOrEqualTo(base));
            expect(readingWidth, lessThanOrEqualTo(820));
            expect(readingWidth, greaterThan(0));
          } else {
            expect(padding.left, base);
          }
          expect(padding.right, padding.left);
          expect(padding.top, size.width < 700 ? 28 : 34);
          expect(tester.takeException(), isNull);
        }
      }
      expect(vm.editor.text, '# A title\n\nReadable body text.');
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
  }

  testWidgets('split reading and writing have the same compact margins', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = fakeWorkspace();
    vm.editor.session.replace('# Title\n\nBody');
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    vm.setLayout(WorkspaceLayout.sourceRender);
    await tester.pumpAndSettle();
    final reading = tester.widget<SuperListView>(
      find.descendant(
        of: find.byType(WorkspacePanes),
        matching: find.byType(SuperListView),
      ),
    );
    expect(reading.padding, const EdgeInsets.fromLTRB(34, 24, 34, 70));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
