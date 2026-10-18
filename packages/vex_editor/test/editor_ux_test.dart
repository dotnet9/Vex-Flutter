import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/src/code_highlighting.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  test('emphasis uses real italic faces without changing source spacing', () {
    const fonts = MarkdownFontFamilies(
      serif: 'SimSun',
      serifFallback: ['serif'],
      sansItalic: 'Segoe UI',
      serifItalic: 'Georgia',
    );
    final sans = fonts.emphasis(
      const TextStyle(fontFamily: 'Microsoft YaHei UI'),
    );
    final serif = fonts.emphasis(const TextStyle(fontFamily: 'SimSun'));
    expect(sans.fontFamily, 'Segoe UI');
    expect(serif.fontFamily, 'Georgia');
    expect(sans.fontFamilyFallback, ['SimSun', 'serif']);
    expect(sans.fontStyle, FontStyle.italic);
    expect(sans.letterSpacing, isNull);
  });

  test('language aliases, filtering and highlighting preserve source', () {
    expect(MarkdownCodeHighlighting.canonical('C#'), 'csharp');
    expect(MarkdownCodeHighlighting.canonical('js'), 'javascript');
    expect(MarkdownCodeHighlighting.matching('c#').first, 'csharp');
    expect(MarkdownCodeHighlighting.matching('py'), contains('python'));
    expect(MarkdownCodeHighlighting.matching('not-a-language'), isEmpty);
    for (final entry in {
      'cs': 'using System; class Program { string x = "Vex"; }',
      'dart': 'final title = "Vex";',
      'js': 'const title = "Vex";',
      'python': 'print("Vex")',
      'sql': 'SELECT * FROM documents WHERE id = 1;',
      'xml': '<title>Vex</title>',
    }.entries) {
      final span = MarkdownCodeHighlighting.span(
        entry.value,
        entry.key,
        const TextStyle(fontSize: 14),
        Brightness.light,
      );
      expect(span.toPlainText(), entry.value);
      expect(span.children, isNotEmpty, reason: entry.key);
    }
    final long = 'x' * 40000;
    expect(
      MarkdownCodeHighlighting.span(long, 'dart', null, Brightness.light).text,
      long,
    );
  });

  testWidgets('arrows move within prose and across block boundaries', (
    tester,
  ) async {
    final controller = MarkdownEditorController(
      text: 'first line\nsecond line\n\nlast block',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
      ),
    );
    await tester.tap(find.text('first line\nsecond line'));
    await tester.pumpAndSettle();
    TextEditingController input() => tester
        .widget<TextField>(find.byKey(const ValueKey('instant-active-input')))
        .controller!;
    input().selection = const TextSelection.collapsed(offset: 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(input().selection.extentOffset, 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(input().selection.extentOffset, greaterThan(10));
    input().selection = TextSelection.collapsed(offset: input().text.length);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(input().text, 'last block');
    expect(input().selection.extentOffset, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(input().text, 'first line\nsecond line');
    expect(input().selection.extentOffset, input().text.length);
    expect(controller.session.isDirty, isFalse);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('language menu filters, selects and keeps code active', (
    tester,
  ) async {
    final controller = MarkdownEditorController(
      text: '```text\nclass Program {}\n```\n\nAfter',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
      ),
    );
    await tester.tap(find.text('class Program {}'));
    await tester.pumpAndSettle();
    final language = find.byKey(const ValueKey('instant-code-language'));
    await tester.enterText(language, 'c#');
    await tester.pumpAndSettle();
    expect(find.text('C#'), findsOneWidget);
    expect(find.text('python'), findsNothing);
    await tester.tap(find.text('C#'));
    await tester.pumpAndSettle();
    expect(controller.text, contains('```csharp'));
    expect(language, findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('instant-active-input')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  for (final source in [
    '- first\n- second\n- third',
    '1. first\n2. second\n3. third',
    '- [x] first\n- [ ] second',
    '- first\n  - child\n- second',
  ]) {
    testWidgets(
      'activating a list does not move the following block: $source',
      (tester) async {
        final controller = MarkdownEditorController(text: '$source\n\nAfter');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.text('After'));
        await tester.tap(find.text('first'));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('After')), rect);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('After')), rect);
        expect(controller.session.isDirty, isFalse);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
