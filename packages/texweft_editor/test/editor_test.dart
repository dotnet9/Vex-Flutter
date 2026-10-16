import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  testWidgets(
    'code language appears below the active block and never in reading',
    (tester) async {
      final controller = MarkdownEditorController(
        text: '```markdown\n# 这是代码\n```\n\n正文\n',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownInstantEditor(
              controller: controller,
              padding: const EdgeInsets.all(20),
            ),
          ),
        ),
      );
      final body = find.byKey(const ValueKey('instant-active-input'));
      final language = find.byKey(const ValueKey('instant-code-language'));
      expect(language, findsNothing);
      expect(find.text('markdown'), findsNothing);
      expect(find.text('复制'), findsNothing);
      await tester.tap(find.text('# 这是代码'));
      await tester.pump();
      expect(language, findsOneWidget);
      expect(
        tester.getTopLeft(language).dy,
        greaterThan(tester.getBottomLeft(body).dy),
      );
      expect(tester.widget<TextField>(body).controller!.text, '# 这是代码');
      await tester.tap(language);
      await tester.enterText(language, 'dart');
      await tester.pump();
      expect(body, findsOneWidget);
      expect(controller.text, '```dart\n# 这是代码\n```\n\n正文\n');
      await tester.enterText(body, 'print("你好");');
      await tester.pump();
      expect(controller.text, '```dart\nprint("你好");\n```\n\n正文\n');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.text, '```markdown\n# 这是代码\n```\n\n正文\n');
      expect(controller.session.canUndo, isFalse);
      expect(language, findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownReader(data: controller.text)),
        ),
      );
      expect(find.byType(SelectableText), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('markdown'), findsNothing);
      expect(find.text('复制'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'code composition, completion and undo preserve the shared document',
    (tester) async {
      const original = '~~~text\r\nold\r\n~~~\r\n';
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      await tester.tap(find.text('old'));
      await tester.pump();
      final body = find.byKey(const ValueKey('instant-active-input'));
      final field = tester.widget<TextField>(body).controller!;
      field.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      await tester.pump();
      expect(controller.text, original);
      field.value = const TextEditingValue(
        text: '你\n好',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pump();
      expect(controller.text, '~~~text\r\n你\r\n好\r\n~~~\r\n');
      expect(controller.selection.extentOffset, '~~~text\r\n你\r\n好'.length);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.byKey(const ValueKey('instant-code-language')), findsNothing);
      controller.session.undo();
      await tester.pump();
      expect(controller.text, original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

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
