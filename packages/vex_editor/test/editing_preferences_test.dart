import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  test(
    'pairs insert, skip and erase without affecting paste or composition',
    () {
      const formatter = MarkdownPairFormatter();
      TextEditingValue value(
        String text,
        int offset, {
        TextRange composing = TextRange.empty,
      }) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset),
        composing: composing,
      );
      expect(
        formatter.formatEditUpdate(value('', 0), value('(', 1)),
        value('()', 1),
      );
      expect(
        formatter.formatEditUpdate(value('()', 1), value('())', 2)),
        value('()', 2),
      );
      expect(
        formatter.formatEditUpdate(value('()', 1), value(')', 0)),
        value('', 0),
      );
      expect(
        formatter.formatEditUpdate(value('', 0), value('(paste)', 7)),
        value('(paste)', 7),
      );
      expect(
        formatter.formatEditUpdate(value('word', 4), value("word'", 5)),
        value("word'", 5),
      );
      final composing = value(
        '(',
        1,
        composing: const TextRange(start: 0, end: 1),
      );
      expect(formatter.formatEditUpdate(value('', 0), composing), composing);
      final selected = TextEditingValue(
        text: 'word',
        selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      );
      final surrounded = formatter.formatEditUpdate(selected, value('[', 1));
      expect(surrounded.text, '[word]');
      expect(
        surrounded.selection,
        const TextSelection(baseOffset: 1, extentOffset: 5),
      );
    },
  );
  test('indentation honors tab stops, selected lines, CRLF and reverse', () {
    final controller = TextEditingController(text: 'ab');
    addTearDown(controller.dispose);
    controller.selection = const TextSelection.collapsed(offset: 2);
    indentMarkdownSelection(controller, 4);
    expect(controller.text, 'ab  ');
    controller.value = const TextEditingValue(
      text: 'a\r\nb\r\nc',
      selection: TextSelection(baseOffset: 0, extentOffset: 6),
    );
    indentMarkdownSelection(controller, 4);
    expect(controller.text, '    a\r\n    b\r\nc');
    indentMarkdownSelection(controller, 4, reverse: true);
    expect(controller.text, 'a\r\nb\r\nc');
  });
  test(
    'editing preferences clamp persisted numbers and reject unknown fonts',
    () {
      final preferences = MarkdownEditingPreferences.fromJson({
        'font': 'unavailable',
        'codeSize': 80,
        'indent': 3,
        'autoPair': false,
        'codeWrap': true,
      });
      expect(preferences.font, MarkdownBodyFont.system);
      expect(preferences.codeSize, 20);
      expect(preferences.indent, 2);
      expect(preferences.autoPair, isFalse);
      expect(preferences.codeWrap, isTrue);
      expect(
        MarkdownEditingPreferences.fromJson(preferences.toJson()).toJson(),
        preferences.toJson(),
      );
    },
  );
  testWidgets(
    'code wrap, independent code size and body font apply to rendered blocks',
    (tester) async {
      const preferences = MarkdownEditingPreferences(
        codeSize: 18,
        codeWrap: true,
        font: MarkdownBodyFont.mono,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: MarkdownReader(
                data: 'Body\n\n```dart\nlong long long long long long long long long long code\n```',
                editingPreferences: preferences,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      final code = tester.widget<SelectableText>(
        find.byType(SelectableText).last,
      );
      expect(code.style?.fontSize, 18);
      final context = tester.element(find.byType(MarkdownReader));
      final sheet = tester
          .widget<MarkdownReader>(find.byType(MarkdownReader))
          .styleSheet(context);
      expect(sheet.p?.fontFamily, 'monospace');
      expect(sheet.p?.letterSpacing, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
