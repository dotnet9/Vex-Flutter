import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  for (final compact in [false, true]) {
    for (final size in [15.0, 20.0]) {
      testWidgets('code footer reserves space: compact=$compact size=$size', (
        tester,
      ) async {
        final controller = MarkdownEditorController(
          text:
              '```dart\nfirst line\nsecond line\n```\n\nFollowing paragraph\n',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MarkdownInstantEditor(
                controller: controller,
                compact: compact,
                fontSize: size,
              ),
            ),
          ),
        );
        final following = find.text('Following paragraph');
        final before = tester.getRect(following);
        await tester.tap(find.text('first line\nsecond line'));
        await tester.pumpAndSettle();
        expect(tester.getRect(following), before);
        final language = find.byKey(const ValueKey('instant-code-language'));
        expect(tester.getSize(language).height, 26);
        await tester.tap(language);
        await tester.enterText(language, 'typescript');
        await tester.pumpAndSettle();
        expect(tester.getRect(following), before);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.getRect(following), before);
        expect(language, findsNothing);
        expect(controller.text, contains('```dart'));
        expect(controller.session.canUndo, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      });
    }
  }
}
