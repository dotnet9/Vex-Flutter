import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'navigation cancels on replacement and disposal: reduced=$reducedMotion',
      (tester) async {
        final source = List.generate(
          100,
          (i) => '## Heading $i\n\nText $i\n\n',
        ).join();
        final editor = MarkdownEditorController(text: source);
        editor.reveal(source.indexOf('## Heading 90\n'));
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reducedMotion),
              child: child!,
            ),
            home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 40));
        editor.reveal(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        editor.session.replace('Short document');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(find.text('Short document', findRichText: true), findsOneWidget);
        expect(find.text('Heading 90', findRichText: true), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(editor.text, 'Short document');
        editor.dispose();
      },
    );
  }

  testWidgets(
    'instant explicit navigation reveals distant and repeated targets without edits',
    (tester) async {
      final source = List.generate(
        100,
        (i) => '## Heading $i\n\nParagraph $i\n\n',
      ).join();
      final editor = MarkdownEditorController(text: source);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
        ),
      );
      await tester.pumpAndSettle();
      for (final index in [90, 0, 90]) {
        final start = source.indexOf('## Heading $index\n');
        editor.reveal(start);
        await tester.pumpAndSettle();
        final target = find.text('Heading $index', findRichText: true);
        expect(target, findsOneWidget);
        expect(
          tester
              .getRect(find.byType(MarkdownInstantEditor))
              .contains(tester.getCenter(target)),
          isTrue,
        );
      }
      await tester.tap(find.text('Paragraph 90', findRichText: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('instant-active-input')),
        findsOneWidget,
      );
      editor.reveal(source.indexOf('## Heading 5\n'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('instant-active-input')), findsNothing);
      expect(find.text('Heading 5', findRichText: true), findsOneWidget);
      expect(editor.text, source);
      expect(editor.session.canUndo, isFalse);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source navigation reveals the target without taking search focus',
    (tester) async {
      final source = List.generate(200, (i) => 'Line $i').join('\r\n');
      final editor = MarkdownEditorController(text: source);
      final searchFocus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: searchFocus),
                Expanded(child: MarkdownSourceEditor(controller: editor)),
              ],
            ),
          ),
        ),
      );
      searchFocus.requestFocus();
      await tester.pumpAndSettle();
      for (final index in [180, 0, 180]) {
        editor.reveal(source.indexOf('Line $index\r\n'));
        await tester.pumpAndSettle();
        expect(searchFocus.hasFocus, isTrue);
        if (defaultTargetPlatform == TargetPlatform.windows) {
          final scroll = tester
              .widget<CodeEditor>(find.byType(CodeEditor))
              .scrollController!;
          expect(
            scroll.verticalScroller.offset,
            index == 0 ? lessThanOrEqualTo(26) : greaterThan(1000),
          );
        } else {
          final editable = tester
              .state<EditableTextState>(
                find.descendant(
                  of: find.byType(MarkdownSourceEditor),
                  matching: find.byType(EditableText),
                ),
              )
              .renderEditable;
          final rect = editable.getLocalRectForCaret(editor.selection.extent);
          final position = editable.localToGlobal(rect.center);
          expect(
            tester
                .getRect(find.byType(MarkdownSourceEditor))
                .contains(position),
            isTrue,
          );
        }
      }
      expect(editor.text, source);
      expect(editor.session.canUndo, isFalse);
      await tester.pumpWidget(const SizedBox());
      searchFocus.dispose();
      editor.dispose();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );
}
