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
  testWidgets('native desktop and touch menu layout, hierarchy and commands', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    vm.editor.session.replace('# 菜单与格式\n\n写下想法，看见脉络。\n\n- 整理结构\n- 继续创作\n');
    vm.editor.session.markSaved();
    vm.setLayout(WorkspaceLayout.source);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TexweftApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();
    final directory = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      if (directory == null) return;
      await Directory(directory).create(recursive: true);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$directory/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
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
        await tester.pumpAndSettle();
        if (size.width > 700) {
          await tester.tap(find.text('段落(P)'));
          await tester.pumpAndSettle();
          await capture('1280-${mode.name}-paragraph');
          await tester.tapAt(const Offset(900, 80));
          await tester.pumpAndSettle();
          await tester.tap(find.text('格式(O)'));
          await tester.pumpAndSettle();
          await capture('1280-${mode.name}-format');
          await tester.tapAt(const Offset(900, 80));
        } else {
          await tester.tap(find.byKey(const ValueKey('workspace-more-menu')));
          await tester.pumpAndSettle();
          await capture('390-${mode.name}-root');
          await tester.tap(find.byKey(const ValueKey('touch-menu-format')));
          await tester.pumpAndSettle();
          await capture('390-${mode.name}-format');
          await tester.tap(find.byTooltip(vm.strings.close).hitTestable().last);
        }
        await tester.pumpAndSettle();
      }
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
