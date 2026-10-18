import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  test('localized table header selects its full text and undoes once', () {
    final controller = MarkdownEditorController(text: '既存の文章');
    controller.select(controller.text.length);
    controller.insertTable(
      rows: 1,
      columns: 2,
      columnLabel: (number) => 'Column $number',
    );
    expect(controller.selection.textInside(controller.text), 'Column 1');
    expect(controller.text, contains('| Column 1 | Column 2 |'));
    controller.session.undo();
    expect(controller.text, '既存の文章');
    expect(controller.session.canUndo, isFalse);
    controller.dispose();
  });

  testWidgets(
    'host labels change during editing without resetting input or selection',
    (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\nprint("hello");\n```',
      );
      var labels = const MarkdownEditorLabels(codeLanguage: 'コードの言語');
      Widget app() => MaterialApp(
        home: Scaffold(
          body: MarkdownInstantEditor(controller: controller, labels: labels),
        ),
      );
      await tester.pumpWidget(app());
      await tester.tap(find.text('print("hello");'));
      await tester.pump();
      final field = find.byKey(const ValueKey('instant-active-input'));
      await tester.enterText(field, 'print("こんにちは");');
      await tester.pump();
      final input = tester.widget<TextField>(field).controller!;
      input.selection = const TextSelection(baseOffset: 7, extentOffset: 12);
      final selection = input.selection;
      labels = const MarkdownEditorLabels(codeLanguage: '程式碼語言');
      await tester.pumpWidget(app());
      await tester.pump();
      expect(tester.widget<TextField>(field).controller, same(input));
      expect(input.selection, selection);
      expect(input.text, 'print("こんにちは");');
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '程式碼語言',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  test(
    'table insertion preserves CRLF and replaces a selection in one undo',
    () {
      const original = '前文\r\n\r\n替换\r\n\r\n后文';
      final controller = MarkdownEditorController(text: original);
      addTearDown(controller.dispose);
      final start = original.indexOf('替换');
      controller.select(start + 2, start);
      controller.insertTable(rows: 1, columns: 2);
      expect(
        controller.text,
        '前文\r\n\r\n| 标题1 | 标题2 |\r\n| --- | --- |\r\n\r\n后文',
      );
      expect(controller.selection.textInside(controller.text), '标题1');
      controller.session.undo();
      expect(controller.text, original);
      expect(controller.session.canUndo, isFalse);
      expect(
        () => controller.insertTable(rows: 0, columns: 2),
        throwsRangeError,
      );
      expect(controller.text, original);
    },
  );

  testWidgets(
    'instant selection maps both ends to CRLF source for formatting',
    (tester) async {
      final controller = MarkdownEditorController(
        text: '```text\r\n前文\r\n后文\r\n```\r\n',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      await tester.tap(find.text('前文\n后文'));
      await tester.pump();
      final body = find.byKey(const ValueKey('instant-active-input'));
      final field = tester.widget<TextField>(body).controller!;
      field.selection = const TextSelection(baseOffset: 5, extentOffset: 3);
      await tester.pump();
      expect(controller.selection.baseOffset, '```text\r\n前文\r\n后文'.length);
      expect(controller.selection.extentOffset, '```text\r\n前文\r\n'.length);
      expect(controller.session.canUndo, isFalse);
      controller.surround('**');
      await tester.pump();
      expect(controller.text, '```text\r\n前文\r\n**后文**\r\n```\r\n');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'Enter in a heading creates a body paragraph and preserves following text',
    (tester) async {
      final controller = MarkdownEditorController(text: '# 左右\r\n\r\n后文\r\n');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      await tester.tap(find.text('左右'));
      await tester.pump();
      final body = find.byKey(const ValueKey('instant-active-input'));
      await tester.enterText(body, '左\n右');
      await tester.pump();
      expect(controller.text, '# 左\r\n\r\n右\r\n\r\n后文\r\n');
      expect(tester.widget<TextField>(body).controller!.text, '右');
      expect(tester.widget<TextField>(body).style!.fontSize, 15);
      controller.session.undo();
      await tester.pump();
      expect(controller.text, '# 左右\r\n\r\n后文\r\n');
      await tester.tap(find.text('左右'));
      await tester.pump();
      await tester.enterText(body, '左右\n');
      await tester.pump();
      expect(tester.widget<TextField>(body).controller!.text, '');
      await tester.enterText(body, '新段落');
      await tester.pump();
      expect(controller.text, '# 左右\r\n\r\n新段落\r\n\r\n后文\r\n');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'instant editing places the caret at the tap and arrows cross block boundaries',
    (tester) async {
      final controller = MarkdownEditorController(
        text: '这是一段较长的正文用于检查光标位置。\n\n第二段正文。\n',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      final paragraph = find.text('这是一段较长的正文用于检查光标位置。');
      await tester.tapAt(tester.getTopLeft(paragraph) + const Offset(2, 14));
      await tester.pump();
      final body = find.byKey(const ValueKey('instant-active-input'));
      var field = tester.widget<TextField>(body).controller!;
      expect(field.selection.extentOffset, lessThan(field.text.length));
      field.selection = TextSelection.collapsed(offset: field.text.length);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      field = tester.widget<TextField>(body).controller!;
      expect(field.text, '第二段正文。');
      expect(field.selection.extentOffset, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(field.text, '这是一段较长的正文用于检查光标位置。');
      expect(field.selection.extentOffset, field.text.length);
      expect(controller.session.canUndo, isFalse);
      controller.session.markSaved();
      await tester.pump();
      expect(body, findsOneWidget);
      await tester.enterText(body, '保存过的改动');
      await tester.pump();
      controller.session.markSaved();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.text, '这是一段较长的正文用于检查光标位置。\n\n第二段正文。\n');
      expect(controller.session.isDirty, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

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
      await tester.tap(find.text('Start with your first sentence…'));
      await tester.pump();
      final field = find.byKey(const ValueKey('instant-active-input'));
      await tester.enterText(field, '你');
      await tester.pump();
      expect(field, findsOneWidget);
      await tester.enterText(field, '你好，维刻');
      await tester.pump();
      expect(controller.session.text, '你好，维刻');
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
