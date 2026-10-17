import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  testWidgets('instant caret centers at start, middle, end, mouse and typing', (
    tester,
  ) async {
    final controller = MarkdownEditorController(
      text: List.generate(60, (i) => 'Line $i').join('\n'),
    );
    final enabled = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: enabled,
            builder: (context, value, _) => MarkdownInstantEditor(
              controller: controller,
              typewriter: value,
              focusMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(
      tester.getTopLeft(find.text(controller.text)) + const Offset(10, 12),
    );
    await tester.pumpAndSettle();
    final body = find.byKey(const ValueKey('instant-active-input'));
    final field = tester.widget<TextField>(body).controller!;
    Future<void> check(int offset) async {
      field.selection = TextSelection.collapsed(offset: offset);
      await tester.pumpAndSettle();
      await tester.pump();
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText).first)
          .renderEditable;
      final caret = editable.getLocalRectForCaret(field.selection.extent);
      final y = editable.localToGlobal(caret.center).dy;
      final viewport = tester.getRect(find.byType(MarkdownInstantEditor));
      expect(y, closeTo(viewport.center.dy, 1));
    }

    await check(0);
    await check(controller.text.indexOf('Line 30'));
    await check(controller.text.length);
    field.value = TextEditingValue(
      text: '${field.text}\nMore',
      selection: TextSelection.collapsed(offset: field.text.length + 5),
    );
    await check(field.text.length);
    await tester.tapAt(
      tester.getRect(find.byType(MarkdownInstantEditor)).center +
          const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await check(field.selection.extentOffset);
    enabled.value = false;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    enabled.dispose();
    controller.dispose();
  });

  testWidgets(
    'Windows source centers first and last lines without editing text',
    (tester) async {
      final controller = MarkdownEditorController(
        text: List.generate(100, (i) => 'Line $i').join('\n'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownSourceEditor(
              controller: controller,
              typewriter: true,
            ),
          ),
        ),
      );
      controller.sourceFocus.requestFocus();
      for (final line in [0, 50, 99, 1]) {
        controller.select(
          !controller.text.contains('Line $line\n')
              ? controller.text.indexOf('Line $line')
              : controller.text.indexOf('Line $line\n'),
        );
        await tester.pumpAndSettle();
        final code = tester.widget<CodeEditor>(find.byType(CodeEditor));
        expect(
          code.scrollController!.verticalScroller.offset,
          closeTo(line * 14 * 1.9, 1),
        );
        expect(
          code.padding!.resolve(TextDirection.ltr).top,
          closeTo((600 - 14 * 1.9) / 2, 1),
        );
      }
      expect(controller.session.isDirty, isFalse);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('platform TextField source centers actual wrapped caret', (
    tester,
  ) async {
    final controller = MarkdownEditorController(
      text: List.generate(100, (i) => 'Line $i').join('\n'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownSourceEditor(controller: controller, typewriter: true),
        ),
      ),
    );
    controller.sourceFocus.requestFocus();
    for (final offset in [
      0,
      controller.text.indexOf('Line 50'),
      controller.text.length,
    ]) {
      controller.select(offset);
      await tester.pumpAndSettle();
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final caret = editable.getLocalRectForCaret(controller.selection.extent);
      expect(editable.localToGlobal(caret.center).dy, closeTo(300, 1));
    }
    expect(controller.session.isDirty, isFalse);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
