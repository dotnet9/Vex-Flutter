import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

Future<void> openWithKeyboard(WidgetTester tester, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(
    shift ? LogicalKeyboardKey.f10 : LogicalKeyboardKey.contextMenu,
  );
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

void main() {
  testWidgets(
    'source keyboard menus retain backward CRLF selection and caret',
    (tester) async {
      final editor = MarkdownEditorController(
        text: List.generate(100, (i) => '$i ${'long text ' * 30}').join('\r\n'),
      );
      final requests = <MarkdownContextRequest>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownSourceEditor(
              controller: editor,
              lineNumbers: false,
              onContextMenu: requests.add,
            ),
          ),
        ),
      );
      final start = editor.text.indexOf('50 ');
      editor.select(start + 280, start + 260);
      editor.sourceFocus.requestFocus();
      await tester.pumpAndSettle();
      final selection = editor.selection;
      for (final shift in [false, true]) {
        await openWithKeyboard(tester, shift: shift);
        await tester.pumpAndSettle();
        expect(requests, hasLength(shift ? 2 : 1));
        expect(requests.last.selection, selection);
        expect(requests.last.keyboard, isTrue);
        expect(requests.last.offset, selection.start);
        final viewport = tester.getRect(find.byType(MarkdownSourceEditor));
        expect(viewport.contains(requests.last.position), isTrue);
        expect(editor.selection, selection);
        expect(editor.session.canUndo, isFalse);
      }
      editor.source.value = editor.source.value.copyWith(
        composing: TextRange(start: selection.start, end: selection.end),
      );
      await tester.pump();
      await openWithKeyboard(tester, shift: true);
      expect(requests, hasLength(2));
      editor.source.clearComposing();
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('instant keyboard menu uses the mapped source selection', (
    tester,
  ) async {
    final editor = MarkdownEditorController(text: '# Heading\r\n\r\n正文第二行\r\n');
    final requests = <MarkdownContextRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownInstantEditor(
            controller: editor,
            onContextMenu: requests.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('正文第二行'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('instant-active-input')),
    );
    field.controller!.selection = const TextSelection(
      baseOffset: 4,
      extentOffset: 1,
    );
    await tester.pump();
    final selection = editor.selection;
    for (final shift in [false, true]) {
      await openWithKeyboard(tester, shift: shift);
      expect(requests, hasLength(shift ? 2 : 1));
      expect(requests.last.selection, selection);
      expect(requests.last.keyboard, isTrue);
      expect(requests.last.offset, editor.text.indexOf('文'));
      expect(
        tester
            .getRect(find.byType(MarkdownInstantEditor))
            .contains(requests.last.position),
        isTrue,
      );
      expect(editor.selection.textInside(editor.text), '文第二');
    }
    field.controller!.value = field.controller!.value.copyWith(
      composing: const TextRange(start: 1, end: 4),
    );
    await openWithKeyboard(tester);
    expect(requests, hasLength(2));
    field.controller!.clearComposing();
    await tester.pumpWidget(const SizedBox());
    editor.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('table keyboard menu captures the focused escaped-pipe cell', (
    tester,
  ) async {
    const source = '| A | B |\r\n| --- | --- |\r\n| a\\|b | value |\r\n';
    final editor = MarkdownEditorController(text: source);
    final requests = <MarkdownContextRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownInstantEditor(
            controller: editor,
            onContextMenu: requests.add,
          ),
        ),
      ),
    );
    final cell = find.byKey(const ValueKey('table-cell-1-0'));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(cell).controller!;
    input.selection = const TextSelection(baseOffset: 3, extentOffset: 1);
    await tester.pump();
    final selection = editor.selection;
    for (final shift in [false, true]) {
      await openWithKeyboard(tester, shift: shift);
      expect(requests, hasLength(shift ? 2 : 1));
      expect(requests.last.tableRow, 1);
      expect(requests.last.tableColumn, 0);
      expect(requests.last.selection, selection);
      expect(requests.last.keyboard, isTrue);
      expect(tester.getRect(cell).contains(requests.last.position), isTrue);
    }
    expect(editor.text, source);
    expect(editor.session.canUndo, isFalse);
    input.value = input.value.copyWith(
      composing: const TextRange(start: 1, end: 3),
    );
    await openWithKeyboard(tester);
    expect(requests, hasLength(2));
    input.clearComposing();
    await tester.pumpWidget(const SizedBox());
    editor.dispose();
    expect(tester.takeException(), isNull);
  });
}
