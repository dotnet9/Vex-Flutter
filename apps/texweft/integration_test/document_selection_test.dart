import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/data/services/desktop_window.dart';
import 'package:texweft/domain/workspace.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native document selection retains layout, source and undo', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    const source =
        '写下第一个想法。\r\n\r\n# 看见脉络\r\n\r\n'
        '```dart\r\nfinal idea = "Vex";\r\n```\r\n\r\n'
        '| 名称 | 状态 |\r\n| --- | --- |\r\n| 想法 | 整理中 |\r\n\r\n'
        '让想法 **慢慢成形**。';
    vm.editor.session.replace(source);
    vm.editor.session.markSaved();
    vm.setLayout(WorkspaceLayout.instant);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TexweftApp(viewModel: vm, windowIntegration: true),
      ),
    );

    Offset caret(String text, int offset) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is RichText && widget.text.toPlainText() == text,
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

    final output = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      if (output == null) return;
      await Directory(output).create(recursive: true);
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
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

    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      for (var i = 0; i < 3; i++) {
        final actual = tester.view.physicalSize / tester.view.devicePixelRatio;
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
        vm.setLayout(WorkspaceLayout.instant);
        vm.editor.select(0);
        await tester.pumpAndSettle();
        await capture('${size.width.toInt()}-${mode.name}-before');
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.down(caret('写下第一个想法。', 2));
        await tester.pump();
        await mouse.moveTo(caret('让想法 慢慢成形。', 6));
        await tester.pump();
        await mouse.up();
        await tester.pumpAndSettle();
        expect(
          vm.editor.selection,
          TextSelection(
            baseOffset: 2,
            extentOffset: source.indexOf('慢慢成形') + 2,
          ),
        );
        expect(vm.editor.text, source);
        expect(vm.editor.session.isDirty, isFalse);
        await capture('${size.width.toInt()}-${mode.name}-selected');
        await tester.enterText(
          find.byKey(const ValueKey('instant-document-selection-input')),
          '新的想法',
        );
        await tester.pumpAndSettle();
        expect(
          vm.editor.text,
          source.replaceRange(2, source.indexOf('慢慢成形') + 2, '新的想法'),
        );
        await capture('${size.width.toInt()}-${mode.name}-replaced');
        vm.editor.session.undo();
        await tester.pumpAndSettle();
        expect(vm.editor.text, source);
        expect(vm.editor.session.isDirty, isFalse);
      }
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
