import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

import 'document_selection_test.dart' show caret;

const captureKey = ValueKey('instant-document-selection-input');
const startKey = ValueKey('instant-selection-start-handle');
const endKey = ValueKey('instant-selection-end-handle');

Future<void> moveHandle(
  WidgetTester tester,
  Key key,
  Offset oldCaret,
  Offset newCaret,
) async {
  final from = tester.getCenter(find.byKey(key));
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(const Offset(0, 20));
  await tester.pump();
  await gesture.moveTo(newCaret + from - oldCaret);
  await tester.pump();
  await gesture.up();
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

  Widget app(
    MarkdownEditorController controller,
    TargetPlatform platform, {
    ValueChanged<MarkdownContextRequest>? onContextMenu,
  }) => MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: MarkdownInstantEditor(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 70),
        onContextMenu: onContextMenu,
      ),
    ),
  );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  ContextMenuButtonItem action(
    WidgetTester tester,
    ContextMenuButtonType type,
  ) => tester
      .widget<AdaptiveTextSelectionToolbar>(
        find.byType(AdaptiveTextSelectionToolbar),
      )
      .buttonItems!
      .singleWhere((item) => item.type == type);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform long press and handles cross blocks with source mapping',
      (tester) async {
        phone(tester);
        const original =
            'First **bold** tail.\r\n\r\n# Heading\r\n\r\nLast line';
        final controller = MarkdownEditorController(text: original);
        final requests = <MarkdownContextRequest>[];
        await tester.pumpWidget(
          app(controller, platform, onContextMenu: requests.add),
        );
        await tester.pumpAndSettle();
        await tester.longPressAt(caret(tester, 'First bold tail.', 7));
        await tester.pumpAndSettle();
        expect(controller.selection.textInside(original), 'bold');
        expect(requests, isEmpty);
        expect(find.byKey(startKey), findsOneWidget);
        expect(find.byKey(endKey), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byKey(captureKey)).keyboardType,
          TextInputType.none,
        );
        await moveHandle(
          tester,
          endKey,
          caret(tester, 'First bold tail.', 10),
          caret(tester, 'Last line', 4),
        );
        expect(controller.selection.start, original.indexOf('bold'));
        expect(controller.selection.end, original.indexOf('Last') + 4);
        action(tester, ContextMenuButtonType.copy).onPressed!();
        await tester.pumpAndSettle();
        expect(clipboard, controller.selection.textInside(original));
        await moveHandle(
          tester,
          startKey,
          caret(tester, 'First bold tail.', 6),
          caret(tester, 'First bold tail.', 1),
        );
        expect(controller.selection.start, 1);
        expect(controller.text, original);
        action(tester, ContextMenuButtonType.cut).onPressed!();
        await tester.pumpAndSettle();
        expect(controller.text, 'F line');
        controller.session.undo();
        await tester.pumpAndSettle();
        expect(controller.text, original);
        expect(controller.session.canUndo, isFalse);
        expect(find.byKey(startKey), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }

  testWidgets(
    'touch scroll does not select; active native selection promotes to document handles',
    (tester) async {
      phone(tester);
      final original = List.generate(
        40,
        (i) => 'Paragraph $i with words.',
      ).join('\n\n');
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(app(controller, TargetPlatform.android));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(MarkdownInstantEditor),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(captureKey), findsNothing);
      expect(controller.text, original);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tapAt(caret(tester, 'Paragraph 0 with words.', 5));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('instant-active-input'));
      final editable = tester
          .state<EditableTextState>(
            find.descendant(of: input, matching: find.byType(EditableText)),
          )
          .renderEditable;
      final position = editable.localToGlobal(
        editable.getLocalRectForCaret(const TextPosition(offset: 5)).center,
      );
      await tester.longPressAt(position);
      await tester.pumpAndSettle();
      expect(find.byKey(startKey), findsOneWidget);
      expect(controller.selection.textInside(original), 'Paragraph');
      expect(
        tester.widget<TextField>(find.byKey(captureKey)).keyboardType,
        TextInputType.multiline,
      );
      await tester.enterText(find.byKey(captureKey), '新的段落');
      await tester.pumpAndSettle();
      expect(controller.text, original.replaceFirst('Paragraph', '新的段落'));
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, original);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'table selection promotes, clipboard replacement and external collapse stay safe',
    (tester) async {
      phone(tester);
      const original =
          '| A | B |\r\n| --- | --- |\r\n| a\\|b | keep |\r\n\r\nLast line';
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(app(controller, TargetPlatform.android));
      await tester.pumpAndSettle();
      await tester.longPressAt(caret(tester, 'keep', 2));
      await tester.pumpAndSettle();
      expect(controller.selection.textInside(original), 'keep');
      expect(find.byKey(endKey), findsOneWidget);
      await moveHandle(
        tester,
        endKey,
        caret(tester, 'keep', 4),
        caret(tester, 'Last line', 4),
      );
      expect(controller.selection.end, original.indexOf('Last') + 4);
      clipboard = '替换';
      action(tester, ContextMenuButtonType.paste).onPressed!();
      await tester.pumpAndSettle();
      expect(
        controller.text,
        original.replaceRange(
          original.indexOf('keep'),
          original.indexOf('Last') + 4,
          '替换',
        ),
      );
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, original);
      await tester.longPressAt(caret(tester, 'Last line', 2));
      await tester.pumpAndSettle();
      controller.select(0);
      await tester.pumpAndSettle();
      expect(find.byKey(startKey), findsNothing);
      expect(find.byKey(captureKey), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'emoji endpoints, select all and tapping a cell dismiss the document selection',
    (tester) async {
      phone(tester);
      const original =
          'Start 👨‍👩‍👧‍👦 end\n\n| A | B |\n| --- | --- |\n| one | two |';
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(app(controller, TargetPlatform.android));
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .byWidgetPredicate(
              (w) =>
                  w is RichText &&
                  w.text.toPlainText() == 'Start 👨‍👩‍👧‍👦 end',
            )
            .first,
      );
      final emoji = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 6, extentOffset: 17),
          )
          .first
          .toRect();
      await tester.longPressAt(
        paragraph.localToGlobal(emoji.centerLeft + Offset(emoji.width / 4, 0)),
      );
      await tester.pumpAndSettle();
      expect(controller.selection.textInside(original), '👨‍👩‍👧‍👦');
      expect(find.byKey(startKey), findsOneWidget);
      expect(find.byKey(endKey), findsOneWidget);
      action(tester, ContextMenuButtonType.selectAll).onPressed!();
      await tester.pumpAndSettle();
      expect(controller.selection.textInside(original), original);
      expect(
        tester
            .widget<AdaptiveTextSelectionToolbar>(
              find.byType(AdaptiveTextSelectionToolbar),
            )
            .buttonItems!
            .where((item) => item.type == ContextMenuButtonType.selectAll),
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('table-cell-1-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(startKey), findsNothing);
      expect(find.byKey(captureKey), findsNothing);
      expect(controller.text, original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'selection more action preserves the range and a handle tap restores the toolbar',
    (tester) async {
      phone(tester);
      final controller = MarkdownEditorController(text: 'First thought.');
      final requests = <MarkdownContextRequest>[];
      await tester.pumpWidget(
        app(controller, TargetPlatform.android, onContextMenu: requests.add),
      );
      await tester.pumpAndSettle();
      await tester.longPressAt(caret(tester, 'First thought.', 2));
      await tester.pumpAndSettle();
      final selection = controller.selection;
      action(tester, ContextMenuButtonType.custom).onPressed!();
      await tester.pumpAndSettle();
      expect(requests.single.selection, selection);
      expect(requests.single.keyboard, isFalse);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      await tester.tap(find.byKey(endKey));
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(controller.selection, selection);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'link long press keeps its element menu instead of starting text selection',
    (tester) async {
      phone(tester);
      const original = 'A [Link](https://example.com) tail.';
      final controller = MarkdownEditorController(text: original);
      final requests = <MarkdownContextRequest>[];
      await tester.pumpWidget(
        app(controller, TargetPlatform.iOS, onContextMenu: requests.add),
      );
      await tester.pumpAndSettle();
      await tester.longPressAt(caret(tester, 'A Link tail.', 3));
      await tester.pumpAndSettle();
      expect(requests.single.offset, original.indexOf('[Link]'));
      expect(find.byKey(captureKey), findsNothing);
      expect(controller.text, original);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'standalone editor preserves native collapsed and mouse table menus',
    (tester) async {
      phone(tester);
      final controller = MarkdownEditorController(
        text: 'First thought.\n\n| A | B |\n| --- | --- |\n| one | two |',
      );
      await tester.pumpWidget(app(controller, TargetPlatform.android));
      await tester.pumpAndSettle();
      await tester.tapAt(caret(tester, 'First thought.', 2));
      await tester.pumpAndSettle();
      final prose = find.byKey(const ValueKey('instant-active-input'));
      var state = tester.state<EditableTextState>(
        find.descendant(of: prose, matching: find.byType(EditableText)),
      );
      expect(
        tester.widget<TextField>(prose).contextMenuBuilder!(
          tester.element(prose),
          state,
        ),
        isA<AdaptiveTextSelectionToolbar>(),
      );
      final cell = find.byKey(const ValueKey('table-cell-1-0'));
      await tester.tap(cell, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      state = tester.state<EditableTextState>(
        find.descendant(of: cell, matching: find.byType(EditableText)),
      );
      state.widget.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(cell).contextMenuBuilder!(
          tester.element(cell),
          state,
        ),
        isA<AdaptiveTextSelectionToolbar>(),
      );
      expect(find.byKey(captureKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'toolbar stays available when only the selection end is visible',
    (tester) async {
      phone(tester);
      final original =
          '${List.filled(350, 'Word').join(' ')}\n\nLast paragraph';
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(app(controller, TargetPlatform.android));
      await tester.pumpAndSettle();
      await tester.longPressAt(caret(tester, original.split('\n').first, 2));
      await tester.pumpAndSettle();
      action(tester, ContextMenuButtonType.selectAll).onPressed!();
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      action(tester, ContextMenuButtonType.copy).onPressed!();
      await tester.pumpAndSettle();
      expect(clipboard, original);
      expect(controller.text, original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'touch handle edge scroll stops and external changes clear handles',
    (tester) async {
      phone(tester);
      final original = List.generate(80, (i) => 'Paragraph $i.').join('\n\n');
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(app(controller, TargetPlatform.android));
      await tester.pumpAndSettle();
      await tester.longPressAt(caret(tester, 'Paragraph 0.', 3));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(endKey)),
      );
      await gesture.moveBy(const Offset(0, 25));
      await tester.pump();
      await gesture.moveTo(const Offset(150, 843));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(scroll.pixels, greaterThan(50));
      expect(
        controller.selection.end,
        greaterThan(original.indexOf('Paragraph 20.')),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      final stopped = scroll.pixels;
      await tester.pump(const Duration(seconds: 1));
      expect(scroll.pixels, stopped);
      expect(controller.text, original);
      controller.session.replace('External');
      await tester.pumpAndSettle();
      expect(find.byKey(startKey), findsNothing);
      expect(find.byKey(endKey), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
