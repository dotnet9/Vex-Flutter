import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  test(
    'Chinese composition commits once, with shared history and selection',
    () {
      final controller = MarkdownEditorController(text: '前文');
      addTearDown(controller.dispose);
      controller.source.value = const TextEditingValue(
        text: '前文ni',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      );
      expect(controller.session.text, '前文');
      controller.source.value = const TextEditingValue(
        text: '前文你',
        selection: TextSelection.collapsed(offset: 3),
      );
      expect(controller.session.text, '前文你');
      controller.session.undo();
      expect(controller.source.text, '前文');
      expect(controller.selection.extentOffset, 2);
    },
  );
  test(
    'find supports Unicode boundaries; replace-all is one undo operation',
    () {
      final controller = MarkdownEditorController(text: 'cat cats cat\n中文 🧵');
      addTearDown(controller.dispose);
      expect(controller.find('cat', wholeWord: true).length, 2);
      controller.replaceAll('cat', '猫', wholeWord: true);
      expect(controller.text, '猫 cats 猫\n中文 🧵');
      controller.session.undo();
      expect(controller.text, 'cat cats cat\n中文 🧵');
      expect(
        () => controller.find('[', regularExpression: true),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'empty instant editor retains its input through first keystrokes',
    (tester) async {
      final controller = MarkdownEditorController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      await tester.tap(find.text('从第一句话开始…'));
      await tester.pump();
      final field = find.byKey(const ValueKey('instant-active-input'));
      await tester.enterText(field, '你');
      await tester.pump();
      expect(field, findsOneWidget);
      await tester.enterText(field, '你好，笺纬');
      await tester.pump();
      expect(controller.session.text, '你好，笺纬');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.session.text, '');
      expect(controller.session.canUndo, isFalse);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('source and instant views share chapter commands and undo', (
    tester,
  ) async {
    final controller = MarkdownEditorController(text: '# 标题\n\n正文\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(child: MarkdownSourceEditor(controller: controller)),
              Expanded(
                child: MarkdownInstantEditor(
                  controller: controller,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.session.renameHeading(
      controller.document.headings.first.id,
      '新标题',
    );
    await tester.pump();
    expect(find.text('新标题'), findsOneWidget);
    expect(controller.source.text, contains('# 新标题'));
    controller.session.undo();
    await tester.pump();
    expect(find.text('标题'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
