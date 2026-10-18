import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

Offset paragraphPoint(RenderParagraph paragraph, int offset) {
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .first
      .toRect();
  return paragraph.localToGlobal(box.center);
}

void main() {
  testWidgets(
    'inline links share a paragraph while retaining tap, secondary and long-press targets',
    (tester) async {
      final contexts = <(String, int)>[], taps = <String>[];
      Widget reader({bool dark = false, bool updated = false}) => MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: Scaffold(
          body: MarkdownReader(
            data: 'Before **bold** [**first**](https://same) after [second](https://same).',
            selectable: false,
            onTapLink: (_, url, _) => taps.add(updated ? 'updated' : url!),
            onMediaContext: (url, image, occurrence, _) =>
                contexts.add((url, occurrence)),
          ),
        ),
      );
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      final rich = find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText() == 'Before bold first after second.',
      );
      expect(rich, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      final linkStyle = paragraph.text
          .getSpanForPosition(const TextPosition(offset: 13))!
          .style!;
      expect(linkStyle.fontWeight, FontWeight.w700);
      expect(linkStyle.fontSize, 15);
      expect(linkStyle.letterSpacing, 0);
      final first = paragraphPoint(paragraph, 13),
          second = paragraphPoint(paragraph, 25);
      await tester.tapAt(first);
      await tester.pumpAndSettle();
      expect(taps, ['https://same']);
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouse.down(second);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(contexts, [('https://same', 1)]);
      await tester.longPressAt(first);
      await tester.pumpAndSettle();
      expect(contexts.last, ('https://same', 0));
      expect(taps, hasLength(1));
      await tester.pumpWidget(reader(updated: true));
      await tester.pumpAndSettle();
      await tester.tapAt(first);
      await tester.pumpAndSettle();
      expect(taps.last, 'updated');
      await tester.pumpWidget(reader(dark: true, updated: true));
      await tester.pumpAndSettle();
      await tester.longPressAt(second);
      await tester.pumpAndSettle();
      expect(contexts.last, ('https://same', 1));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, delimiter) in [
    for (final width in [390.0, 650.0, 1280.0])
      for (final delimiter in ['---', ':---:', '---:']) (width, delimiter),
  ]) {
    testWidgets('rich text retains wrapping at $width / $delimiter', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const body =
          '从这里开始，**写下想法**，让 _文字_ 成形。`print("Vex")` 与 [项目](https://vex.dev)。';
      const cellText = '**原文** 与 `code` 末尾';
      final editor = MarkdownEditorController(
        text:
            '$body\n\n后续段落。\n\n'
            '| 名称 | 状态 |\n| $delimiter | --- |\n| $cellText | 整理中 |\n',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownInstantEditor(
              controller: editor,
              onContextMenu: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final following = tester.getRect(find.text('后续段落。'));
      await tester.tap(find.textContaining('从这里开始', findRichText: true).first);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('instant-active-input'));
      final input = tester.widget<TextField>(field).controller!;
      input.selection = const TextSelection.collapsed(offset: body.length);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('后续段落。')), following);
      await tester.tap(find.text('后续段落。'));
      await tester.pumpAndSettle();
      final display = find.byKey(const ValueKey('table-display-1-0'));
      final rich = find.descendant(
        of: display,
        matching: find.byType(RichText),
      );
      final paragraph = tester.renderObject<RenderParagraph>(rich.first);
      final before = paragraphPoint(paragraph, '原文 与 code 末尾'.length - 1);
      final cell = find.byKey(const ValueKey('table-cell-1-0'));
      await tester.tap(cell);
      await tester.pumpAndSettle();
      final tableInput = tester.widget<TextField>(cell).controller!;
      tableInput.selection = const TextSelection.collapsed(
        offset: cellText.length,
      );
      await tester.pumpAndSettle();
      final editable = tester
          .state<EditableTextState>(
            find.descendant(of: cell, matching: find.byType(EditableText)),
          )
          .renderEditable;
      // Compare glyph bounds, not EditableText's full-line selection highlight.
      editable.selectionHeightStyle = BoxHeightStyle.tight;
      final box = editable
          .getBoxesForSelection(
            TextSelection(
              baseOffset: cellText.length - 1,
              extentOffset: cellText.length,
            ),
          )
          .first
          .toRect();
      final after = editable.localToGlobal(box.center);
      expect(after.dx, closeTo(before.dx, .1), reason: 'table horizontal');
      expect(after.dy, closeTo(before.dy, .1), reason: 'table vertical');
      expect(editor.session.canUndo, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    });
  }
}
