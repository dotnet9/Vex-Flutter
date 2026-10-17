import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'task markers remain visible in ${brightness.name} reading mode',
      (tester) async {
        final colors = ColorScheme.fromSeed(
          seedColor: const Color(0xff24766b),
          brightness: brightness,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: colors),
            home: const Scaffold(
              body: MarkdownReader(data: '- [x] Done\n- [ ] Todo\n'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final icon in [Icons.check_box, Icons.check_box_outline_blank]) {
          final marker = tester.widget<Icon>(find.byIcon(icon));
          expect(marker.color, colors.primary);
          expect(marker.size, 15);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'nested lists render and edit as one source-preserving block at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const list =
            '7. Parent\r\n\r\n'
            '   Second paragraph\r\n\r\n'
            '   - Child\r\n'
            '     3. Grandchild\r\n\r\n'
            '8. Next parent\r\n\r\n';
        const source = '# Title\r\n\r\n${list}Tail\r\n';
        final editor = MarkdownEditorController(text: source);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MarkdownInstantEditor(
                controller: editor,
                padding: const EdgeInsets.all(24),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<MarkdownReader>(find.byType(MarkdownReader))
              .where((reader) => reader.data == list),
          hasLength(1),
        );
        expect(find.text('Child', findRichText: true), findsOneWidget);
        expect(find.text('Grandchild', findRichText: true), findsOneWidget);
        await tester.tap(find.text('Child', findRichText: true));
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('instant-active-input'));
        final field = tester.widget<TextField>(input);
        expect(
          field.controller!.text,
          contains('   - Child\n     3. Grandchild'),
        );
        expect(field.controller!.text, isNot(contains('Tail')));
        expect(editor.session.canUndo, isFalse);
        await tester.enterText(
          input,
          field.controller!.text.replaceFirst('Grandchild', 'Changed'),
        );
        await tester.pumpAndSettle();
        expect(editor.text, source.replaceFirst('Grandchild', 'Changed'));
        expect(editor.selection.isValid, isTrue);
        editor.session.undo();
        await tester.pumpAndSettle();
        expect(editor.text, source);
        expect(editor.session.canUndo, isFalse);
        expect(find.text('Grandchild', findRichText: true), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        editor.dispose();
      },
    );
  }
}
