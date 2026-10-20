import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.iOS]) {
    testWidgets('visible panes follow user scrolling without moving the caret', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.editor.session.replace(
        List.generate(
          50,
          (i) =>
              '## Section $i\n\n${List.generate(12, (j) => 'Paragraph $i.$j explains one idea in detail. ' * 5).join('\n\n')}\n',
        ).join('\n'),
      );
      vm.editor.session.markSaved();
      vm.editor.select(7);
      vm.sidebar = false;
      vm.setLayout(WorkspaceLayout.sourceRender);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final caret = vm.editor.selection;
      final revision = vm.editor.session.revision;
      List<MarkdownViewportSync> panes() => tester
          .widgetList<MarkdownViewportSync>(find.byType(MarkdownViewportSync))
          .toList();
      expect(panes(), hasLength(2));

      await tester.drag(
        find.byType(SuperListView).last,
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      var offset = vm.editor.viewport.value!.offset;
      expect(offset, greaterThan(500));
      expect(panes().first.readPosition(), closeTo(offset, 120));
      expect(vm.selectedHeadingId, isNotNull);
      expect(vm.editor.selection, caret);

      // Scrolling inside the same paragraph must continue to move the follower.
      final before = panes().first.scroll.offset;
      await tester.drag(find.byType(SuperListView).last, const Offset(0, -70));
      await tester.pumpAndSettle();
      expect(panes().first.scroll.offset, greaterThan(before));

      // Reverse ownership: dragging source now drives the reading pane.
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(MarkdownSourceEditor)),
          scrollDelta: const Offset(0, 500),
        ),
      );
      await tester.pumpAndSettle();
      offset = vm.editor.viewport.value!.offset;
      expect(panes().last.readPosition(), closeTo(offset, 120));
      expect(vm.editor.selection, caret);
      expect(vm.editor.session.revision, revision);
      expect(vm.editor.session.isDirty, isFalse);

      // Newly opened views inherit the current continuous source coordinate.
      vm.setLayout(WorkspaceLayout.instantMap);
      await tester.pumpAndSettle();
      expect(panes(), hasLength(1));
      expect(panes().single.readPosition(), closeTo(offset, 120));
      final document = vm.editor.document;
      vm.updateAppearance(palette: 'rose', mode: ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(identical(vm.editor.document, document), isTrue);
      expect(panes().single.readPosition(), closeTo(offset, 120));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }, variant: TargetPlatformVariant.only(platform));
  }
}
