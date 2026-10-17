import 'dart:io';
import 'dart:ui' as ui;

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
  testWidgets('native nested list rendering, editing and undo', (tester) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    const source =
        '# 章节清单\r\n\r\n'
        '7. 整理想法\r\n\r\n'
        '   补充一段说明。\r\n\r\n'
        '   - 子任务\r\n'
        '     3. 细分步骤\r\n'
        '     4. 校对内容\r\n'
        '   - [x] 已完成\r\n\r\n'
        '8. 继续写作\r\n\r\n'
        '列表后的正文。\r\n';
    vm.editor.session.replace(source);
    vm.editor.session.markSaved();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TexweftApp(viewModel: vm, windowIntegration: true),
      ),
    );
    final output = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      if (output == null) return;
      await Directory(output).create(recursive: true);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
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
        await tester.pumpAndSettle();
        expect(find.text('细分步骤', findRichText: true), findsOneWidget);
        await capture('${size.width.toInt()}-${mode.name}-instant');
        await tester.tap(find.text('子任务', findRichText: true));
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('instant-active-input'));
        final controller = tester.widget<TextField>(input).controller!;
        expect(controller.text, contains('   - 子任务\n     3. 细分步骤'));
        await tester.enterText(
          input,
          controller.text.replaceFirst('细分步骤', '已修改步骤'),
        );
        await tester.pumpAndSettle();
        expect(vm.editor.text, source.replaceFirst('细分步骤', '已修改步骤'));
        await capture('${size.width.toInt()}-${mode.name}-editing');
        vm.editor.session.undo();
        await tester.pumpAndSettle();
        expect(vm.editor.text, source);
        expect(vm.editor.session.isDirty, isFalse);
        vm.setLayout(WorkspaceLayout.read);
        await tester.pumpAndSettle();
        expect(find.text('细分步骤', findRichText: true), findsOneWidget);
        await capture('${size.width.toInt()}-${mode.name}-reading');
      }
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
