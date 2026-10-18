import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  for (final layout in [WorkspaceLayout.read, WorkspaceLayout.instant]) {
    testWidgets('appearance keeps the visible document block in ${layout.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.editor.session.replace(
        List.generate(
          180,
          (i) =>
              '## Section $i\n\n${List.filled(45, 'Reading position stays with this paragraph.').join(' ')}\n',
        ).join('\n'),
      );
      vm.editor.session.markSaved();
      vm.setLayout(layout);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      SuperListView view() => tester.widget(find.byType(SuperListView).last);
      final list = view().listController!, scroll = view().controller!;
      list.jumpToItem(index: 201, scrollController: scroll, alignment: 0);
      await tester.pumpAndSettle();
      scroll.jumpTo(scroll.offset + 30);
      await tester.pumpAndSettle();
      final visible = list.visibleRange!.$1;
      final source = vm.editor.text, revision = vm.editor.session.revision;
      for (final typography in MarkdownTypography.values) {
        vm.updateAppearance(typography: typography, fontSize: 24);
        await tester.pump();
        expect(
          list.visibleRange!.$1,
          visible,
          reason: 'first ${typography.name} frame',
        );
        await tester.pumpAndSettle();
        expect(list.visibleRange!.$1, visible, reason: typography.name);
        expect(tester.takeException(), isNull);
      }
      vm.updateAppearance(fontSize: 12, compact: true, contentZoom: 1.25);
      await tester.pumpAndSettle();
      expect(list.visibleRange!.$1, visible);
      tester.view.physicalSize = const Size(820, 900);
      await tester.pumpAndSettle();
      expect(list.visibleRange!.$1, visible, reason: 'window width');
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(list.visibleRange!.$1, visible, reason: 'system text scale');
      vm.updateAppearance(typography: MarkdownTypography.simple);
      vm.selectHeading(vm.editor.document.headings[120]);
      await tester.pumpAndSettle();
      expect(find.text('Section 120').hitTestable(), findsOneWidget);
      expect(vm.editor.text, source);
      expect(vm.editor.session.revision, revision);
      expect(vm.editor.session.isDirty, isFalse);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
  }
}
