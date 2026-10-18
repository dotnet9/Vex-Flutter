import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native touch selection spans paragraphs, code and tables', (
    tester,
  ) async {
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    const source =
        'First **bold** thought.\r\n\r\n# 看见脉络\r\n\r\n'
        '```dart\r\nfinal idea = "Vex";\r\n```\r\n\r\n'
        '| 名称 | 状态 |\r\n| --- | --- |\r\n| 想法 | 整理中 |\r\n\r\n'
        'Last line，慢慢成形。';
    vm.editor.session.replace(source);
    vm.editor.session.markSaved();
    vm.setLayout(WorkspaceLayout.instant);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    Offset caret(String text, int offset) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .byWidgetPredicate(
              (w) => w is RichText && w.text.toPlainText() == text,
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

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      final directory = Platform.isAndroid
          ? '${(await getExternalStorageDirectory())!.path}/touch-review'
          : Platform.environment['VEX_CAPTURE_DIR'];
      if (directory == null) return;
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      try {
        await Directory(directory).create(recursive: true);
        await File('$directory/$name.png').writeAsBytes(
          (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
              .asUint8List(),
        );
      } finally {
        image.dispose();
      }
    }

    ContextMenuButtonItem action(ContextMenuButtonType type) => tester
        .widget<AdaptiveTextSelectionToolbar>(
          find.byType(AdaptiveTextSelectionToolbar),
        )
        .buttonItems!
        .singleWhere((item) => item.type == type);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      vm.updateAppearance(mode: mode);
      vm.editor.select(0);
      await tester.pumpAndSettle();
      final width =
          (tester.view.physicalSize.width / tester.view.devicePixelRatio)
              .round();
      await tester.longPressAt(caret('First bold thought.', 7));
      await tester.pumpAndSettle();
      expect(vm.editor.selection.textInside(source), 'bold');
      await capture('$width-${mode.name}-word');
      final handle = find.byKey(const ValueKey('instant-selection-end-handle'));
      final from = tester.getCenter(handle);
      final oldCaret = caret('First bold thought.', 10);
      final to = caret('Last line，慢慢成形。', 4);
      final touch = await tester.startGesture(from);
      await touch.moveBy(const Offset(0, 20));
      await tester.pump();
      await touch.moveTo(to + from - oldCaret);
      await tester.pump();
      await touch.up();
      await tester.pumpAndSettle();
      expect(vm.editor.selection.start, source.indexOf('bold'));
      expect(vm.editor.selection.end, source.indexOf('Last') + 4);
      expect(vm.editor.text, source);
      expect(vm.editor.session.isDirty, isFalse);
      await capture('$width-${mode.name}-cross-block');
      final selection = vm.editor.selection;
      await Clipboard.setData(const ClipboardData(text: '新的想法'));
      action(ContextMenuButtonType.paste).onPressed!();
      await tester.pumpAndSettle();
      expect(
        vm.editor.text,
        source.replaceRange(selection.start, selection.end, '新的想法'),
      );
      await capture('$width-${mode.name}-replaced');
      vm.editor.session.undo();
      await tester.pumpAndSettle();
      expect(vm.editor.text, source);
      expect(vm.editor.session.isDirty, isFalse);
      vm.editor.select(0);
      await tester.pumpAndSettle();
      await tester.longPressAt(caret('想法', 1));
      await tester.pumpAndSettle();
      final cellSelection = vm.editor.selection;
      expect(cellSelection.isCollapsed, isFalse);
      expect(cellSelection.start, greaterThanOrEqualTo(source.indexOf('想法')));
      expect(cellSelection.end, lessThanOrEqualTo(source.indexOf('想法') + 2));
      expect(
        find.byKey(const ValueKey('instant-selection-end-handle')),
        findsOneWidget,
      );
      await capture('$width-${mode.name}-table-word');
      action(ContextMenuButtonType.selectAll).onPressed!();
      await tester.pumpAndSettle();
      expect(vm.editor.selection.textInside(source), source);
      action(ContextMenuButtonType.copy).onPressed!();
      await tester.pumpAndSettle();
      expect((await Clipboard.getData(Clipboard.kTextPlain))?.text, source);
      await capture('$width-${mode.name}-select-all');
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
