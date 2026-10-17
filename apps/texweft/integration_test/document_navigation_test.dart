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
  testWidgets('native document navigation preserves content in every pane', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    final source =
        '# 文内导航\n\n[跳到末尾](#目标)\n\n'
        '${List.generate(80, (i) => '段落 $i\n\n').join()}'
        '## 目标\n\n写下想法，看见脉络。\n\n';
    vm.editor.session.replace(source);
    vm.editor.session.markSaved();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TexweftApp(viewModel: vm, windowIntegration: true),
      ),
    );
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
        for (final layout in [
          WorkspaceLayout.instant,
          WorkspaceLayout.source,
          WorkspaceLayout.read,
        ]) {
          vm.setLayout(layout);
          await tester.pumpAndSettle();
          vm.followAnchor('#');
          await tester.pumpAndSettle();
          if (layout == WorkspaceLayout.read) {
            await tester.tap(find.text('跳到末尾', findRichText: true));
          } else {
            vm.selectHeading(vm.editor.document.headings.last);
          }
          await tester.pumpAndSettle();
          expect(vm.selectedHeading?.title, '目标');
          expect(vm.editor.text, source);
          expect(vm.editor.session.isDirty, isFalse);
          await capture('${size.width.toInt()}-${mode.name}-${layout.name}');
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
