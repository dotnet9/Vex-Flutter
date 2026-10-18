import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  testWidgets('reader paints text directly and copies a dragged selection', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownReader(data: 'First paragraph.\n\nSecond paragraph.'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    final first = find.text('First paragraph.', findRichText: true);
    final second = find.text('Second paragraph.', findRichText: true);
    final start = tester.getTopLeft(first) + const Offset(1, 10);
    final end = tester.getTopRight(second) + const Offset(-1, 10);
    final mouse = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await mouse.moveTo(end);
    await mouse.up();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(copied, contains('First paragraph.'));
    expect(copied, contains('Second paragraph.'));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('reader reuses an existing selection area', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectionArea(child: MarkdownReader(data: 'Body')),
        ),
      ),
    );
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(find.text('Body', findRichText: true), findsOneWidget);
  });
}
