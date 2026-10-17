import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  for (final typography in MarkdownTypography.values) {
    for (final compact in [false, true]) {
      testWidgets('${typography.name}/$compact click keeps text geometry', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final prefix in [
          '# ',
          '## ',
          '### ',
          '#### ',
          '##### ',
          '###### ',
          '',
        ]) {
          final controller = MarkdownEditorController(
            text: '$prefix固定文字位置\n\n后续段落不会移动\n',
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MarkdownInstantEditor(
                  key: UniqueKey(),
                  controller: controller,
                  typography: typography,
                  compact: compact,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final following = tester.getRect(find.text('后续段落不会移动'));
          final rich = find.descendant(
            of: find.text('固定文字位置'),
            matching: find.byType(RichText),
          );
          final paragraph = tester.renderObject<RenderParagraph>(rich.first);
          final before = paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 1),
              )
              .first;
          final origin = paragraph.localToGlobal(
            Offset(before.left, before.top),
          );
          await tester.tap(find.text('固定文字位置'));
          await tester.pumpAndSettle();
          final editable = tester
              .state<EditableTextState>(find.byType(EditableText).first)
              .renderEditable;
          final after = editable
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 1),
              )
              .first;
          final active = editable.localToGlobal(Offset(after.left, after.top));
          expect(
            active.dx,
            closeTo(origin.dx, .01),
            reason: '$prefix horizontal',
          );
          expect(
            active.dy,
            closeTo(origin.dy, .01),
            reason: '$prefix vertical',
          );
          expect(
            tester.getRect(find.text('后续段落不会移动')),
            following,
            reason: '$prefix following block',
          );
          expect(controller.session.isDirty, isFalse);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      });
    }
  }
}
