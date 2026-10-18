import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:vex_editor/src/source_controller.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'navigation maps backward UTF-16 selection without changing mixed EOL',
    () {
      const original = '甲🧵\r\n乙\n丙\r丁\r\n';
      final editor = MarkdownEditorController(text: original);
      final code = MarkdownSourceEditingController(editor);
      addTearDown(editor.dispose);
      addTearDown(code.dispose);

      editor.select(original.length, 1);
      expect(code.selection.baseIndex, 4);
      expect(code.selection.baseOffset, 0);
      expect(code.selection.extentIndex, 0);
      expect(code.selection.extentOffset, 1);
      code.selection = const CodeLineSelection(
        baseIndex: 3,
        baseOffset: 1,
        extentIndex: 1,
        extentOffset: 0,
      );
      expect(editor.selection.textInside(original), '乙\n丙\r丁');
      expect(
        editor.selection.baseOffset,
        greaterThan(editor.selection.extentOffset),
      );
      expect(editor.session.text, original);
      expect(editor.session.isDirty, isFalse);
      expect(editor.session.canUndo, isFalse);
    },
  );

  test('typing and multiline paste preserve untouched mixed line endings', () {
    const original = '甲\r\n乙\n丙\r丁\r\n';
    final editor = MarkdownEditorController(text: original);
    final code = MarkdownSourceEditingController(editor);
    addTearDown(editor.dispose);
    addTearDown(code.dispose);

    editor.select(original.indexOf('丙'), original.indexOf('丙') + 1);
    code.replaceSelection('新\n行');
    expect(editor.text, '甲\r\n乙\n新\r\n行\r丁\r\n');
    expect(editor.selection.extentOffset, editor.text.indexOf('行') + 1);
    code.undo();
    expect(editor.text, original);
    expect(editor.session.isDirty, isFalse);
    code.redo();
    expect(editor.text, '甲\r\n乙\n新\r\n行\r丁\r\n');
  });

  test('composing text stays out of history until committed', () {
    final editor = MarkdownEditorController(text: '头\r\n尾');
    final code = MarkdownSourceEditingController(editor);
    addTearDown(editor.dispose);
    addTearDown(code.dispose);
    editor.select(3);

    code.value = CodeLineEditingValue(
      codeLines: CodeLines.fromText('头\nni尾'),
      selection: const CodeLineSelection.collapsed(index: 1, offset: 2),
      composing: const TextRange(start: 0, end: 2),
    );
    expect(editor.text, '头\r\nni尾');
    expect(editor.source.value.composing, const TextRange(start: 3, end: 5));
    expect(editor.session.text, '头\r\n尾');
    expect(code.canUndo, isFalse);
    code.undo();
    expect(editor.source.text, '头\r\nni尾');

    code.value = CodeLineEditingValue(
      codeLines: CodeLines.fromText('头\n你尾'),
      selection: const CodeLineSelection.collapsed(index: 1, offset: 1),
    );
    expect(editor.session.text, '头\r\n你尾');
    expect(editor.source.value.composing, TextRange.empty);
    code.undo();
    expect(editor.text, '头\r\n尾');
  });

  test('deleting one of adjacent mixed EOLs uses the actual selection', () {
    final editor = MarkdownEditorController(text: '甲\r\n\n乙\r丙');
    final code = MarkdownSourceEditingController(editor);
    addTearDown(editor.dispose);
    addTearDown(code.dispose);
    editor.select(1, 3);
    code.replaceSelection('');
    expect(editor.text, '甲\n乙\r丙');
    code.undo();
    editor.select(3);
    code.deleteBackward();
    expect(editor.text, '甲\n乙\r丙');
    code.undo();
    editor.select(1);
    code.deleteForward();
    expect(editor.text, '甲\n乙\r丙');
  });

  test('source Enter keeps task continuation, fence rules and shared undo', () {
    final editor = MarkdownEditorController(text: '- [x] 完成');
    final code = MarkdownSourceEditingController(editor);
    addTearDown(editor.dispose);
    addTearDown(code.dispose);
    editor.select(editor.text.length);
    code.applyNewLine();
    expect(editor.text, '- [x] 完成\n- [ ] ');
    code.applyNewLine();
    expect(editor.text, '- [x] 完成\n\n');
    code.undo();
    expect(editor.text, '- [x] 完成');
    editor.session.replace('```md\r\n- code\r\n```');
    editor.select(editor.text.indexOf('\r\n```'));
    code.applyNewLine();
    expect(editor.text, '```md\r\n- code\r\n\r\n```');
  });

  test('toolbar and chapter edits enter the same source undo stack', () {
    final editor = MarkdownEditorController(text: '# 标题\r\n正文');
    final code = MarkdownSourceEditingController(editor);
    addTearDown(editor.dispose);
    addTearDown(code.dispose);
    editor.select(6, 8);
    editor.surround('**');
    expect(code.text, '# 标题\n**正文**');
    editor.session.renameHeading(editor.document.headings.first.id, '修改标题');
    expect(code.text, '# 修改标题\n**正文**');
    code.undo();
    expect(code.text, '# 标题\n**正文**');
    code.undo();
    expect(code.text, '# 标题\n正文');
    expect(code.canUndo, isFalse);
    expect(code.delegate.canUndo, isFalse);
  });

  testWidgets('platform input and keyboard undo reach the shared document', (
    tester,
  ) async {
    final editor = MarkdownEditorController(text: '初始');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MarkdownSourceEditor(controller: editor)),
      ),
    );
    editor.select(0, 2);
    editor.sourceFocus.requestFocus();
    await tester.pump();
    expect(tester.testTextInput.isRegistered, isTrue);
    final client =
        (tester.testTextInput.log
                    .lastWhere((call) => call.method == 'TextInput.setClient')
                    .arguments
                as List)
            .first;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingStateWithDeltas', [
          client,
          {
            'deltas': [
              {
                'oldText': '初始',
                'deltaText': '替换🧵',
                'deltaStart': 0,
                'deltaEnd': 2,
                'selectionBase': 4,
                'selectionExtent': 4,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': -1,
                'composingExtent': -1,
              },
            ],
          },
        ]),
      ),
      (_) {},
    );
    await tester.pump();
    expect(editor.text, '替换🧵');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(editor.text, '初始');
    expect(editor.session.isDirty, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    editor.dispose();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'source restores both scroll axes and reveals external selection',
    (tester) async {
      final editor = MarkdownEditorController(
        text: List.generate(500, (i) => '$i ${'long text ' * 100}').join('\n'),
      );
      final visible = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: visible,
              builder: (context, show, _) => show
                  ? MarkdownSourceEditor(controller: editor)
                  : const SizedBox(),
            ),
          ),
        ),
      );
      var scroll = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .scrollController!;
      for (final fraction in [.85, .15, 1.0, 0.0]) {
        final target =
            scroll.verticalScroller.position.maxScrollExtent * fraction;
        scroll.verticalScroller.jumpTo(target);
        await tester.pump();
        expect(scroll.verticalScroller.offset, closeTo(target, 1));
        expect(tester.takeException(), isNull);
      }
      scroll.verticalScroller.jumpTo(700);
      scroll.horizontalScroller.jumpTo(120);
      await tester.pump();
      visible.value = false;
      await tester.pump();
      visible.value = true;
      await tester.pump();
      scroll = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .scrollController!;
      expect(scroll.verticalScroller.offset, 700);
      expect(scroll.horizontalScroller.offset, 120);

      editor.select(editor.text.lastIndexOf('499 '));
      editor.sourceFocus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(scroll.verticalScroller.offset, greaterThan(700));
      expect(editor.session.isDirty, isFalse);
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      visible.dispose();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'a pending clipboard paste is harmless after closing the editor',
    (tester) async {
      final pending = Completer<Object?>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? pending.future : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final editor = MarkdownEditorController(text: '保留原文');
      final code = MarkdownSourceEditingController(editor);
      code.paste();
      code.dispose();
      editor.dispose();
      pending.complete({'text': '迟到的剪贴板'});
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
