import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  const source = '| Name | Other |\r\n| --- | --- |\r\n| Original | Keep |\r\n';
  const candidate = TextEditingValue(
    text: 'Originalnihao',
    selection: TextSelection.collapsed(offset: 13),
    composing: TextRange(start: 8, end: 13),
  );
  const key = ValueKey('table-cell-1-0');

  testWidgets(
    'candidate text survives appearance, selection and viewport rebuilds',
    (tester) async {
      final editor = MarkdownEditorController(text: source);
      Widget app({
        Brightness brightness = Brightness.light,
        double fontSize = 15,
      }) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: MarkdownInstantEditor(controller: editor, fontSize: fontSize),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final cell = find.byKey(key);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(cell).controller!;
      input.value = candidate;
      await tester.pump();
      expect(editor.text, source);
      expect(editor.session.canUndo, isFalse);
      await tester.pumpWidget(app(brightness: Brightness.dark, fontSize: 18));
      await tester.pumpAndSettle();
      expect(input.value, candidate);
      editor.select(source.indexOf('Original'));
      await tester.pumpAndSettle();
      expect(input.value, candidate);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(input.value, candidate);
      input.value = const TextEditingValue(
        text: 'Original你好',
        selection: TextSelection.collapsed(offset: 10),
      );
      await tester.pumpAndSettle();
      expect(editor.text, source.replaceFirst('Original', 'Original你好'));
      editor.session.undo();
      await tester.pumpAndSettle();
      expect(editor.text, source);
      expect(editor.session.canUndo, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    },
  );

  testWidgets(
    'external edits invalidate the candidate without writing it back',
    (tester) async {
      final editor = MarkdownEditorController(text: source);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
        ),
      );
      await tester.pumpAndSettle();
      final cell = find.byKey(key);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(cell).controller!;
      input.value = candidate;
      editor.session.replace(source.replaceFirst('Original', 'External'));
      // Even a pending platform commit before the next frame is stale.
      input.value = const TextEditingValue(
        text: 'Original你好',
        selection: TextSelection.collapsed(offset: 10),
      );
      await tester.pumpAndSettle();
      expect(editor.text, source.replaceFirst('Original', 'External'));
      expect(input.text, 'External');
      expect(input.value.composing, TextRange.empty);
      editor.session.undo();
      await tester.pumpAndSettle();
      expect(editor.text, source);
      expect(editor.session.canUndo, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    },
  );

  testWidgets(
    'cancelled candidate after another cell changes allows further typing',
    (tester) async {
      final editor = MarkdownEditorController(text: source);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
        ),
      );
      await tester.pumpAndSettle();
      final cell = find.byKey(key);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(cell).controller!;
      input.value = candidate;
      editor.session.replace(source.replaceFirst('Keep', 'Changed'));
      input.value = const TextEditingValue(
        text: 'Original',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.pumpAndSettle();
      expect(input.text, 'Original');
      input.value = const TextEditingValue(
        text: 'Original!',
        selection: TextSelection.collapsed(offset: 9),
      );
      await tester.pumpAndSettle();
      expect(
        editor.text,
        source
            .replaceFirst('Keep', 'Changed')
            .replaceFirst('Original', 'Original!'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    },
  );

  testWidgets(
    'switching controllers with identical content clears a foreign candidate',
    (tester) async {
      final first = MarkdownEditorController(text: source),
          second = MarkdownEditorController(text: source);
      Widget app(MarkdownEditorController editor) => MaterialApp(
        home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
      );
      await tester.pumpWidget(app(first));
      await tester.pumpAndSettle();
      final cell = find.byKey(key);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      tester.widget<TextField>(cell).controller!.value = candidate;
      await tester.pumpWidget(app(second));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cell).controller!.text, 'Original');
      expect(
        tester.widget<TextField>(cell).controller!.value.composing,
        TextRange.empty,
      );
      expect(first.text, source);
      expect(second.text, source);
      expect(second.session.canUndo, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      first.dispose();
      second.dispose();
    },
  );
}
