import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

Offset caret(WidgetTester tester, String text, int offset) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find
        .byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == text,
        )
        .first,
  );
  final local = paragraph.getOffsetForCaret(
    TextPosition(offset: offset),
    Rect.zero,
  );
  final boxes = paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 1),
  );
  return paragraph.localToGlobal(
    local + Offset(0, boxes.first.toRect().height / 2),
  );
}

Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.down(from);
  await tester.pump();
  await mouse.moveTo(to);
  await tester.pump();
  await mouse.up();
  await tester.pumpAndSettle();
}

Future<void> shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;
  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  const source =
      'First line\r\n\r\n# Heading\r\n\r\n'
      '```dart\r\nfinal n = 1;\r\n```\r\n\r\n'
      '| Name | Other |\r\n| --- | --- |\r\n| value | keep |\r\n\r\n'
      'Last **bold** tail.';
  const captureKey = ValueKey('instant-document-selection-input');

  Widget app(
    MarkdownEditorController controller, {
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
  );

  testWidgets(
    'large shared selection preserves full input and one-step candidate undo',
    (tester) async {
      final original = List.generate(
        1000,
        (i) => 'Paragraph $i with **Markdown** and 中文。',
      ).join('\n\n');
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      controller.select(0, original.length);
      await tester.pumpAndSettle();
      final buffer = find.byKey(captureKey);
      final input = tester.widget<TextField>(buffer).controller!;
      expect(input.text, original);
      expect(
        input.selection,
        TextSelection(baseOffset: 0, extentOffset: original.length),
      );
      input.value = const TextEditingValue(
        text: 'nihao',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(buffer).style!.fontSize, 15);
      expect(controller.text, original);
      input.value = const TextEditingValue(
        text: '你好',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pumpAndSettle();
      expect(controller.text, '你好');
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, original);
      expect(controller.session.canUndo, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'selection extension respects grapheme boundaries and keyboard context',
    (tester) async {
      const original = 'Start\n\nA👨‍👩‍👧‍👦B';
      final controller = MarkdownEditorController(text: original);
      final requests = <MarkdownContextRequest>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownInstantEditor(
              controller: controller,
              onContextMenu: requests.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.select(0, original.length - 1);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(controller.selection.extentOffset, original.indexOf('👨'));
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.selection, controller.selection);
      expect(requests.single.keyboard, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.text, original);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'select-all from an active block targets the document and survives saving',
    (tester) async {
      final controller = MarkdownEditorController(text: source);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First line'));
      await tester.pumpAndSettle();
      await shortcut(tester, LogicalKeyboardKey.keyA);
      expect(
        controller.selection,
        TextSelection(baseOffset: 0, extentOffset: source.length),
      );
      controller.session.markSaved();
      await tester.pumpAndSettle();
      expect(find.byKey(captureKey), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(controller.text, '');
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, source);
      expect(controller.session.isDirty, isFalse);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'table-cell drag maps an escaped pipe into the shared source range',
    (tester) async {
      const original =
          '| A | B |\r\n| --- | --- |\r\n| a\\|b | keep |\r\n\r\nLast line';
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      await drag(
        tester,
        caret(tester, 'a|b', 2),
        caret(tester, 'Last line', 4),
      );
      expect(
        controller.selection,
        TextSelection(
          baseOffset: original.indexOf('a\\|b') + 3,
          extentOffset: original.indexOf('Last') + 4,
        ),
      );
      expect(controller.text, original);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'dragging near the viewport edge scrolls and stops on pointer up',
    (tester) async {
      final original = List.generate(80, (i) => 'Paragraph $i.').join('\n\n');
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(caret(tester, 'Paragraph 0.', 3));
      await tester.pump();
      final rect = tester.getRect(find.byType(MarkdownInstantEditor));
      await mouse.moveTo(Offset(rect.left + 120, rect.bottom - 1));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(scroll.pixels, greaterThan(50));
      expect(
        controller.selection.end,
        greaterThan(original.indexOf('Paragraph 10.')),
      );
      await mouse.up();
      await tester.pumpAndSettle();
      final stopped = scroll.pixels;
      await tester.pump(const Duration(seconds: 1));
      expect(scroll.pixels, stopped);
      expect(controller.text, original);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('a pending paste cannot replace an externally changed document', (
    tester,
  ) async {
    final controller = MarkdownEditorController(text: source);
    final pending = Completer<Map<String, String>>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? pending.future : null,
    );
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    controller.select(0, source.length);
    await tester.pumpAndSettle();
    await shortcut(tester, LogicalKeyboardKey.keyV);
    controller.session.replace('External');
    pending.complete({'text': 'Stale paste'});
    await tester.pumpAndSettle();
    expect(controller.text, 'External');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'forward drag crosses heading, code and table without changing source',
    (tester) async {
      final controller = MarkdownEditorController(text: source);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      final from = caret(tester, 'First line', 2);
      final to = caret(tester, 'Last bold tail.', 7);
      await drag(tester, from, to);
      final selection = controller.selection;
      expect(
        selection,
        TextSelection(baseOffset: 2, extentOffset: source.indexOf('bold') + 2),
      );
      expect(controller.text, source);
      expect(controller.session.canUndo, isFalse);
      expect(find.byKey(captureKey), findsOneWidget);
      await shortcut(tester, LogicalKeyboardKey.keyC);
      expect(clipboard, selection.textInside(source));
      await tester.enterText(find.byKey(captureKey), '新内容');
      await tester.pumpAndSettle();
      expect(
        controller.text,
        source.replaceRange(selection.start, selection.end, '新内容'),
      );
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, source);
      expect(controller.session.canUndo, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'backward drag, shift click and clipboard preserve directed selection',
    (tester) async {
      final controller = MarkdownEditorController(
        text: 'First **bold** tail.\n\nLast line',
      );
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      final from = caret(tester, 'Last line', 6);
      final to = caret(tester, 'First bold tail.', 8);
      await drag(tester, from, to);
      expect(
        controller.selection.baseOffset,
        controller.text.indexOf('Last') + 6,
      );
      expect(
        controller.selection.extentOffset,
        controller.text.indexOf('bold') + 2,
      );
      final selection = controller.selection, original = controller.text;
      await shortcut(tester, LogicalKeyboardKey.keyX);
      expect(
        controller.text,
        original.replaceRange(selection.start, selection.end, ''),
      );
      expect(clipboard, selection.textInside(original));
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, original);
      await tester.tapAt(caret(tester, 'Last line', 4));
      await tester.pumpAndSettle();
      final base = controller.selection.baseOffset;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(
        caret(tester, 'First bold tail.', 2),
        kind: PointerDeviceKind.mouse,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        TextSelection(baseOffset: base, extentOffset: 2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('shared select-all and IME commit form one history entry', (
    tester,
  ) async {
    final controller = MarkdownEditorController(text: source);
    await tester.pumpWidget(app(controller));
    await tester.pumpAndSettle();
    controller.select(0, source.length);
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(find.byKey(captureKey)).controller!;
    input.value = const TextEditingValue(
      text: 'nihao',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 0, end: 5),
    );
    await tester.pumpWidget(app(controller, brightness: Brightness.dark));
    await tester.pumpAndSettle();
    expect(input.text, 'nihao');
    expect(controller.text, source);
    input.value = const TextEditingValue(
      text: '你好',
      selection: TextSelection.collapsed(offset: 2),
    );
    await tester.pumpAndSettle();
    expect(controller.text, '你好');
    controller.session.undo();
    await tester.pumpAndSettle();
    expect(controller.text, source);
    expect(controller.session.canUndo, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'external change or document switch invalidates captured IME input',
    (tester) async {
      final controller = MarkdownEditorController(text: source);
      final other = MarkdownEditorController(text: source);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      controller.select(0, source.length);
      await tester.pumpAndSettle();
      final input = tester
          .widget<TextField>(find.byKey(captureKey))
          .controller!;
      input.value = const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      controller.session.replace('External');
      input.value = const TextEditingValue(
        text: '你',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pumpAndSettle();
      expect(controller.text, 'External');
      other.select(0, source.length);
      await tester.pumpWidget(app(other));
      await tester.pumpAndSettle();
      input.value = const TextEditingValue(
        text: '旧输入',
        selection: TextSelection.collapsed(offset: 3),
      );
      await tester.pumpAndSettle();
      expect(other.text, source);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      other.dispose();
    },
  );
}
