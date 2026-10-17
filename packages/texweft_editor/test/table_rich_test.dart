import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('table rich display, focus and undo remain intact at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const source =
          '| Name | Value |\r\n| --- | ---: |\r\n'
          '| **Bold** | `x` and *emphasis* |\r\n'
          r'| # Literal | $x^2$ |'
          '\r\n';
      final editor = MarkdownEditorController(text: source);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
        ),
      );
      await tester.pumpAndSettle();
      final display = find.byKey(const ValueKey('table-display-1-0'));
      final rich = tester.widgetList<RichText>(
        find.descendant(of: display, matching: find.byType(RichText)),
      );
      expect(rich.map((widget) => widget.text.toPlainText()).join(), 'Bold');
      expect(find.byType(MarkdownMathFormula), findsOneWidget);
      final literal = find.byKey(const ValueKey('table-display-2-0'));
      expect(
        tester
            .widgetList<RichText>(
              find.descendant(of: literal, matching: find.byType(RichText)),
            )
            .map((widget) => widget.text.toPlainText())
            .join(),
        '# Literal',
      );
      final cell = find.byKey(const ValueKey('table-cell-1-0'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(display, findsNothing);
      expect(tester.widget<TextField>(cell).controller!.text, '**Bold**');
      expect(editor.text, source);
      expect(editor.session.canUndo, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('table-cell-1-1')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cell).focusNode!.hasFocus, isTrue);
      await tester.enterText(cell, '**Changed**');
      await tester.pumpAndSettle();
      tester.widget<TextField>(cell).focusNode!.unfocus();
      await tester.pumpAndSettle();
      expect(display, findsOneWidget);
      expect(editor.text, contains('**Changed**'));
      editor.session.undo();
      await tester.pumpAndSettle();
      expect(editor.text, source);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    });
  }
}
