import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  for (final reduced in [true, false]) {
    testWidgets(
      'diagram source resizes and expands with reduced motion=$reduced',
      (tester) async {
        var width = 900.0;
        var expanded = false;
        Widget app() => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: MarkdownMermaidBlock(
                    source: 'flowchart LR\n  A[Draft] --> B[Saved]',
                    sourceEditor: expanded
                        ? const TextField(maxLines: 4)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        for (final next in [390.0, 700.0, 320.0]) {
          width = next;
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final open in [true, false]) {
            expanded = open;
            await tester.pumpWidget(app());
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const ValueKey('mermaid-source')),
              open ? findsOneWidget : findsNothing,
            );
          }
        }
        expect(
          find.byType(AnimatedSize),
          reduced ? findsNothing : findsOneWidget,
        );
      },
    );

    testWidgets('formula resizes with reduced motion=$reduced', (tester) async {
      final controller = MarkdownEditorController(
        text: '\$\$\na^2+b^2=c^2\n\$\$',
      );
      var width = 900.0;
      Widget app() => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MarkdownInstantEditor(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (final next in [390.0, 700.0, 320.0]) {
        width = next;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(
        find.byType(AnimatedSize),
        reduced ? findsNothing : findsOneWidget,
      );
      expect(controller.text, '\$\$\na^2+b^2=c^2\n\$\$');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
