import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native inline editing hides only inactive markers and preserves IME',
    (tester) async {
      await initializeDesktopWindow(size: const Size(1280, 900));
      await windowManager.setMinimumSize(const Size(320, 568));
      final vm = fakeWorkspace(), boundary = GlobalKey();
      await vm.initialize(watchFiles: false);
      const body =
          '从这里开始，**写下想法**，让 _文字_ 成形。`print("Vex")` 与 [项目](https://vex.dev)。';
      const source =
          '# 即时编辑\r\n\r\n$body\r\n\r\n'
          '| 名称 | 状态 |\r\n| --- | --- |\r\n| **原文** 与 `code` 末尾 | 整理中 |\r\n\r\n'
          '```text\r\n**这里保留字面标记**\r\n```\r\n';
      vm.editor.session.replace(source);
      vm.editor.session.markSaved();
      vm.setLayout(WorkspaceLayout.instant);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: VexApp(viewModel: vm, windowIntegration: true),
        ),
      );
      final output = Platform.environment['VEX_CAPTURE_DIR'];
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull, reason: name);
        if (output == null) return;
        await Directory(output).create(recursive: true);
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        try {
          await File('$output/$name.png').writeAsBytes(
            (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
                .asUint8List(),
          );
        } finally {
          image.dispose();
        }
      }

      Offset glyphPoint(RenderParagraph paragraph, int offset) =>
          paragraph.localToGlobal(
            paragraph
                .getBoxesForSelection(
                  TextSelection(baseOffset: offset, extentOffset: offset + 1),
                )
                .first
                .toRect()
                .center,
          );
      void expectGlyph(Finder field, int offset, Offset before) {
        final editable = tester
            .state<EditableTextState>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .renderEditable;
        final heightStyle = editable.selectionHeightStyle;
        editable.selectionHeightStyle = ui.BoxHeightStyle.tight;
        final after = editable.localToGlobal(
          editable
              .getBoxesForSelection(
                TextSelection(baseOffset: offset, extentOffset: offset + 1),
              )
              .first
              .toRect()
              .center,
        );
        editable.selectionHeightStyle = heightStyle;
        expect(after.dx, closeTo(before.dx, .2));
        expect(after.dy, closeTo(before.dy, .2));
      }

      for (final size in [const Size(1280, 900), const Size(390, 844)]) {
        for (var i = 0; i < 3; i++) {
          final actual =
              tester.view.physicalSize / tester.view.devicePixelRatio;
          final outer = await windowManager.getSize();
          await windowManager.setSize(
            Size(
              outer.width + size.width - actual.width,
              outer.height + size.height - actual.height,
            ),
          );
          await tester.pumpAndSettle();
        }
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          vm.updateAppearance(mode: mode);
          await tester.pumpAndSettle();
          // Reset focus so both states can be compared without changing source.
          FocusManager.instance.primaryFocus?.unfocus();
          vm.setLayout(WorkspaceLayout.read);
          await tester.pumpAndSettle();
          vm.setLayout(WorkspaceLayout.instant);
          await tester.pumpAndSettle();
          final bodyRich = find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().startsWith('从这里开始'),
          );
          expect(bodyRich, findsOneWidget);
          final bodyParagraph = tester.renderObject<RenderParagraph>(bodyRich);
          final bodyPoint = glyphPoint(
            bodyParagraph,
            bodyParagraph.text.toPlainText().length - 1,
          );
          final beforeGlyphs = <String, Offset>{
            for (final token in ['从', '写', '文', '成', 'p', '与', '项', '。'])
              token: glyphPoint(
                bodyParagraph,
                bodyParagraph.text.toPlainText().indexOf(token),
              ),
          };
          final tableBefore = tester.getRect(
            find.byKey(const ValueKey('table-cell-1-0')),
          );
          await capture('${size.width.toInt()}-${mode.name}-display');
          await tester.tap(
            find.textContaining('从这里开始', findRichText: true).first,
          );
          await tester.pumpAndSettle();
          final field = find.byKey(const ValueKey('instant-active-input'));
          final input = tester.widget<TextField>(field).controller!;
          expect(input.text, body);
          input.selection = const TextSelection.collapsed(offset: body.length);
          await tester.pumpAndSettle();
          for (final entry in beforeGlyphs.entries) {
            expectGlyph(field, body.indexOf(entry.key), entry.value);
          }
          expectGlyph(field, body.length - 1, bodyPoint);
          expect(
            tester.getRect(find.byKey(const ValueKey('table-cell-1-0'))),
            tableBefore,
          );
          await capture('${size.width.toInt()}-${mode.name}-hidden');
          input.selection = TextSelection.collapsed(
            offset: body.indexOf('写下想法') + 2,
          );
          await tester.pumpAndSettle();
          expect(vm.editor.selection.extentOffset, source.indexOf('写下想法') + 2);
          await capture('${size.width.toInt()}-${mode.name}-current-token');
          input.value = const TextEditingValue(
            text: '$body nihao',
            selection: TextSelection.collapsed(offset: body.length + 6),
            composing: TextRange(start: body.length + 1, end: body.length + 6),
          );
          await tester.pumpAndSettle();
          expect(vm.editor.text, source);
          input.value = const TextEditingValue(
            text: '$body 你好',
            selection: TextSelection.collapsed(offset: body.length + 3),
          );
          await tester.pumpAndSettle();
          expect(vm.editor.text, source.replaceFirst(body, '$body 你好'));
          vm.editor.session.undo();
          await tester.pumpAndSettle();
          expect(vm.editor.text, source);
          final cell = find.byKey(const ValueKey('table-cell-1-0'));
          final cellRich = find.descendant(
            of: find.byKey(const ValueKey('table-display-1-0')),
            matching: find.byType(RichText),
          );
          final cellParagraph = tester.renderObject<RenderParagraph>(
            cellRich.first,
          );
          final cellPoint = glyphPoint(
            cellParagraph,
            cellParagraph.text.toPlainText().length - 1,
          );
          await tester.tap(cell);
          await tester.pumpAndSettle();
          final tableInput = tester.widget<TextField>(cell).controller!;
          tableInput.selection = TextSelection.collapsed(
            offset: tableInput.text.length,
          );
          await tester.pumpAndSettle();
          expectGlyph(cell, tableInput.text.length - 1, cellPoint);
          await capture('${size.width.toInt()}-${mode.name}-table');
          await tester.enterText(cell, '${tableInput.text}！');
          await tester.pumpAndSettle();
          expect(vm.editor.text, source.replaceFirst('末尾', '末尾！'));
          vm.editor.session.undo();
          await tester.pumpAndSettle();
          expect(vm.editor.text, source);
          expect(vm.editor.session.isDirty, isFalse);
        }
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
