import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/ui/core/app_widgets.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('caption keyboard focus is visible and stable in $brightness', (
      tester,
    ) async {
      var closeCount = 0;
      final colors = ColorScheme.fromSeed(
        seedColor: const Color(0xff24766b),
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colors),
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCaptionButton(
                    icon: 'x',
                    tooltip: 'Close',
                    close: true,
                    onPressed: () => closeCount++,
                  ),
                  AppCaptionButton(
                    icon: 'min',
                    tooltip: 'Minimize',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final close = find.byType(AppCaptionButton).first;
      final glyph = find.descendant(of: close, matching: find.byType(AppGlyph));
      final before = tester.getRect(close);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(Focus.of(tester.element(glyph)).hasFocus, isTrue);
      final button = tester.widget<TextButton>(
        find.descendant(of: close, matching: find.byType(TextButton)),
      );
      expect(
        button.style!.side!.resolve({WidgetState.focused}),
        BorderSide(color: colors.primary, width: 2),
      );
      expect(
        button.style!.backgroundColor!.resolve({WidgetState.focused}),
        colors.primaryContainer,
      );
      final material = tester.widget<Material>(
        find.descendant(of: close, matching: find.byType(Material)).first,
      );
      expect(material.color, colors.primaryContainer);
      expect(tester.getRect(close), before);
      expect(before.size, const Size(46, 32));
      expect(closeCount, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(closeCount, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(glyph)).hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
