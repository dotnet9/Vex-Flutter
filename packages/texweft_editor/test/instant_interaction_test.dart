import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  testWidgets('first mouse drag selects text used by the format command', (
    tester,
  ) async {
    final controller = MarkdownEditorController(
      text: 'Select these words to make them bold.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => controller.surround('**'),
                child: const Text('Bold'),
              ),
              Expanded(child: MarkdownInstantEditor(controller: controller)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(
      find.text('Select these words to make them bold.'),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(Offset(rect.left + 2, rect.center.dy));
    await tester.pump();
    await mouse.moveTo(Offset(rect.left + 105, rect.center.dy));
    await tester.pump();
    await mouse.up();
    final selection = controller.selection;
    expect(selection.isCollapsed, isFalse);
    final selected = selection.textInside(controller.text);
    await tester.tap(find.text('Bold'));
    await tester.pumpAndSettle();
    expect(controller.text, contains('**$selected**'));
    controller.session.undo();
    expect(controller.text, 'Select these words to make them bold.');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
    'table cells edit directly, preserve CRLF and pipes, navigate and undo',
    (tester) async {
      const source =
          '前文\r\n\r\n| 标题 | 第二列 |\r\n| --- | --- |\r\n| 原文 | 保留 |\r\n\r\n后文';
      final controller = MarkdownEditorController(text: source);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final cell = find.byKey(const ValueKey('table-cell-1-0'));
      await tester.tap(cell);
      await tester.enterText(cell, '直接|编辑');
      await tester.pumpAndSettle();
      expect(controller.text, contains('| 直接\\|编辑 | 保留 |\r\n'));
      expect(find.byKey(const ValueKey('instant-active-input')), findsNothing);
      final input = tester.widget<TextField>(cell).controller!;
      input.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      controller.surround('**');
      await tester.pumpAndSettle();
      expect(controller.text, contains('| **直接**\\|编辑 | 保留 |'));
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cell).controller!.text, '直接|编辑');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('table-cell-1-1')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, source);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
