import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/src/inline_editing_controller.dart';
import 'package:vex_editor/src/selection_projection.dart';
import 'package:vex_editor/vex_editor.dart';

List<(String, TextStyle)> fragments(TextSpan span) {
  final result = <(String, TextStyle)>[];
  void visit(TextSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span.text case final text?) result.add((text, style));
    for (final child in span.children ?? <InlineSpan>[]) {
      if (child is TextSpan) visit(child, style);
    }
  }

  visit(span, const TextStyle());
  return result;
}

String visible(TextSpan span) =>
    fragments(span)
        .where((entry) => entry.$2.fontSize != 0)
        .map((entry) => entry.$1)
        .join();

void main() {
  const raw =
      'Start **bold** *italic* ~~old~~ `code` [link](https://vex.dev) '
      '==mark== H~2~O x^2^ end';
  testWidgets(
    'only the current token reveals markers while retaining the entire source value',
    (tester) async {
      final input = MarkdownInlineEditingController(text: raw);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      TextSpan span() => input.buildTextSpan(
        context: context,
        style: const TextStyle(fontSize: 15),
        withComposing: true,
      );
      input.selection = const TextSelection.collapsed(offset: raw.length);
      expect(span().toPlainText(), raw);
      expect(
        visible(span()),
        'Start bold italic old code link mark H2O x2 end',
      );
      final runs = fragments(span());
      expect(
        runs.firstWhere((r) => r.$1 == 'bold').$2.fontWeight,
        FontWeight.w700,
      );
      expect(
        runs.firstWhere((r) => r.$1 == 'italic').$2.fontStyle,
        FontStyle.italic,
      );
      expect(
        runs.firstWhere((r) => r.$1 == 'old').$2.decoration,
        TextDecoration.lineThrough,
      );
      input.selection = TextSelection.collapsed(
        offset: raw.indexOf('bold') + 2,
      );
      expect(
        visible(span()),
        'Start **bold** italic old code link mark H2O x2 end',
      );
      input.selection = TextSelection.collapsed(
        offset: raw.indexOf('link') + 2,
      );
      expect(
        visible(span()),
        'Start bold italic old code [link](https://vex.dev) mark H2O x2 end',
      );
      expect(input.text, raw);
      input.dispose();
    },
  );

  test(
    'nested delimiters, escaped markers and code-block content use CommonMark',
    () {
      const text =
          '- **bold _nested_**\n\n  ```text\n  **literal**\n  ```\n\n'
          r'\*\*escaped\*\* and `**code**`';
      final tokens = markdownInlineTokens(text, const MarkdownPreferences());
      expect(
        tokens.where((t) => t.tag == 'strong'),
        hasLength(1),
        reason: tokens
            .map((t) => '${t.tag}: ${t.range.slice(text)}')
            .join(', '),
      );
      expect(tokens.where((t) => t.tag == 'em'), hasLength(1));
      expect(tokens.where((t) => t.tag == 'code'), hasLength(1));
      for (final token in tokens) {
        expect(token.range.slice(text), isNot(contains('literal')));
        expect(token.range.start, lessThanOrEqualTo(token.content.start));
        expect(token.range.end, greaterThanOrEqualTo(token.content.end));
      }
      final disabled = markdownInlineTokens(
        '==mark== H~2~O x^2^ **bold**',
        const MarkdownPreferences(highlight: false, subscript: false),
      );
      expect(disabled.map((t) => t.tag), ['strong']);
      final cell = markdownInlineTokens(
        '```code``` tail',
        const MarkdownPreferences(),
        inlineOnly: true,
      );
      expect(cell.single.tag, 'code');
      expect(cell.single.content.slice('```code``` tail'), 'code');
    },
  );

  testWidgets(
    'hidden marker geometry does not change source selection, IME or history',
    (tester) async {
      const source = 'Before **粗体** and `code` after.\r\n\r\n下一段。';
      final editor = MarkdownEditorController(text: source);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Before 粗体 and code after.', findRichText: true),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('instant-active-input'));
      final input = tester.widget<TextField>(field).controller!;
      input.selection = TextSelection.collapsed(offset: input.text.length);
      await tester.pumpAndSettle();
      final editable = tester
          .state<EditableTextState>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .renderEditable;
      final marker = editable.getBoxesForSelection(
        const TextSelection(baseOffset: 7, extentOffset: 9),
      );
      expect(
        marker.fold<double>(0, (sum, box) => sum + box.toRect().width),
        lessThan(.1),
      );
      input.selection = const TextSelection(baseOffset: 9, extentOffset: 11);
      await tester.pump();
      expect(editor.selection.textInside(editor.text), '粗体');
      final body = input.text;
      input.value = TextEditingValue(
        text: '$body nihao',
        selection: TextSelection.collapsed(offset: body.length + 6),
        composing: TextRange(start: body.length + 1, end: body.length + 6),
      );
      await tester.pumpAndSettle();
      expect(editor.text, source);
      input.value = TextEditingValue(
        text: '$body 你好',
        selection: TextSelection.collapsed(offset: body.length + 3),
      );
      await tester.pumpAndSettle();
      expect(editor.text, source.replaceFirst('after.', 'after. 你好'));
      editor.session.undo();
      await tester.pumpAndSettle();
      expect(editor.text, source);
      expect(editor.session.canUndo, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    },
  );
}
