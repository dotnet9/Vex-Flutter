import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  for (final layout in [WorkspaceLayout.read, WorkspaceLayout.instant]) {
    testWidgets('find reveals text deep inside a long ${layout.name} block', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.sidebar = false;
      vm.editor.session.replace(
        '# Article\n\n${'A short **formatted** sentence and [link](https://example.com/very-long-address). ' * 120}'
        'UniqueSearchTarget ${'A concluding sentence. ' * 60}UniqueSearchTarget\n',
      );
      vm.setLayout(layout);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      vm.search('UniqueSearchTarget');
      for (var result = 0; result < 2; result++) {
        vm.nextMatch();
        await tester.pumpAndSettle();
        final viewport = tester.getRect(find.byType(SuperListView));
        final hitBoxes = <Rect>[];
        for (final object
            in tester.allRenderObjects.whereType<RenderParagraph>().toSet()) {
          final text = object.text.toPlainText();
          var start = text.indexOf('UniqueSearchTarget');
          while (start >= 0) {
            final boxes = object.getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: start + 18),
            );
            hitBoxes.add(
              MatrixUtils.transformRect(
                object.getTransformTo(null),
                boxes.first.toRect(),
              ),
            );
            start = text.indexOf('UniqueSearchTarget', start + 18);
          }
        }
        expect(hitBoxes, hasLength(2));
        expect(viewport.contains(hitBoxes[result].center), isTrue);
      }
      expect(vm.layout, layout);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  for (final layout in WorkspaceLayout.values) {
    testWidgets(
      'find and replace keep ${layout.name} and reveal every visible pane',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final vm = fakeWorkspace();
        final source = List.generate(
          90,
          (i) => '## Section $i\n\nParagraph $i has useful information.\n\n',
        ).join();
        vm.editor.session.replace(source);
        vm.sidebar = false;
        vm.setLayout(layout);
        await tester.pumpWidget(VexApp(viewModel: vm));
        await tester.pumpAndSettle();
        vm.showFind();
        await tester.pumpAndSettle();
        final field = find
            .descendant(
              of: find.byKey(const ValueKey('editor-findbar')),
              matching: find.byType(TextField),
            )
            .first;
        await tester.tap(field);
        await tester.enterText(field, 'Paragraph 75');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(vm.layout, layout);
        expect(
          find.byType(MarkdownSourceEditor),
          layout.panes.contains('source') ? findsOneWidget : findsNothing,
        );
        expect(vm.selectedHeading?.title, 'Section 75');
        expect(vm.editor.sourceFocus.hasFocus, isFalse);
        final offset = source.indexOf('Paragraph 75');
        expect(vm.editor.selection.start, offset);
        for (final list in tester.widgetList<SuperListView>(
          find.byType(SuperListView),
        )) {
          expect(
            list.listController!.visibleRange!.$1,
            inInclusiveRange(148, 151),
          );
        }
        if (layout.panes.contains('map')) {
          expect(vm.map.selectedId, vm.selectedHeadingId);
        }
        final cached = vm.matches;
        vm.nextMatch();
        expect(identical(vm.matches, cached), isTrue);
        vm.showFind(replace: true);
        vm.replaceCurrent('Revised 75');
        await tester.pumpAndSettle();
        expect(vm.layout, layout);
        expect(vm.editor.text, contains('Revised 75'));
        vm.editor.session.undo();
        await tester.pumpAndSettle();
        expect(vm.editor.text, source);
        vm.search('Paragraph');
        vm.replaceMatches('Note');
        await tester.pumpAndSettle();
        expect(vm.editor.text, isNot(contains('Paragraph')));
        expect(vm.layout, layout);
        vm.editor.session.undo();
        expect(vm.editor.text, source);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
