import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  test('insertion retains CRLF, fence boundaries and shared undo', () {
    final controller = MarkdownEditorController(text: '前\r\n\r\n替换\r\n\r\n后');
    addTearDown(controller.dispose);
    controller.select(5, 7);
    final original = controller.text;
    controller.insertMermaid(MermaidTemplate.sequence.source);
    expect(controller.text, contains('```mermaid\r\nsequenceDiagram\r\n'));
    expect(controller.text, endsWith('```\r\n\r\n后'));
    expect(controller.text.replaceAll('\r\n', ''), isNot(contains('\n')));
    controller.session.undo();
    expect(controller.text, original);
    expect(controller.session.canUndo, isFalse);
  });

  testWidgets('reader paints all diagram types without source text', (
    tester,
  ) async {
    for (final template in MermaidTemplate.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownReader(data: template.markdown),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownMermaidBlock), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mermaid-error')),
        findsNothing,
        reason: template.name,
      );
      expect(find.text(template.source), findsNothing);
      expect(tester.takeException(), isNull, reason: template.name);
    }
  });

  testWidgets(
    'source unfolds above persistent preview and Escape keeps edits',
    (tester) async {
      final controller = MarkdownEditorController(
        text: '```mermaid\nflowchart LR\n A --> B\n```\n',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      final preview = find.byKey(const ValueKey('mermaid-preview'));
      final state = tester.state(find.byType(MarkdownMermaidBlock));
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MarkdownMermaidBlock)), same(state));
      final field = find.byKey(const ValueKey('instant-active-input'));
      expect(
        tester.getRect(field).bottom,
        lessThan(tester.getRect(preview).top),
      );
      await tester.enterText(field, 'flowchart LR\n A --> C');
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.text, contains('A --> C'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mermaid-source')), findsNothing);
      expect(controller.text, contains('A --> C'));
      expect(tester.state(find.byType(MarkdownMermaidBlock)), same(state));
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, contains('A --> B'));
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'invalid edits keep last scene and IME commits only at completion',
    (tester) async {
      final controller = MarkdownEditorController(
        text: '```mermaid\nflowchart LR\n A --> B\n```',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('mermaid-preview')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('instant-active-input'));
      final input = tester.widget<TextField>(field).controller!;
      final original = controller.text;
      const intermediate = 'flowchart LR\n A[想法';
      input.value = const TextEditingValue(
        text: intermediate,
        selection: TextSelection.collapsed(offset: intermediate.length),
        composing: TextRange(
          start: intermediate.length - 2,
          end: intermediate.length,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.text, original);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(field, findsOneWidget);
      input.value = input.value.copyWith(composing: TextRange.empty);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('mermaid-error')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mermaid-preview')),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      final invalid = controller.text;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.text, invalid);
      expect(find.byKey(const ValueKey('mermaid-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('renderer strips links and rejects oversized sources', (
    tester,
  ) async {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xff24766b));
    final svg = MarkdownMermaidRenderer.svg(
      'flowchart LR\nA[Safe]\nclick A "javascript:alert(1)"',
      colors,
    );
    expect(svg, isNot(contains('javascript:')));
    expect(svg, isNot(contains('<a ')));
    expect(
      () => MarkdownMermaidRenderer.scene('x' * 65537, colors),
      throwsFormatException,
    );
  });
}
