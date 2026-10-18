import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('custom titlebar, native fullscreen and presentation restore', (
    tester,
  ) async {
    await initializeDesktopWindow();
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();
    final output = Platform.environment['VEX_CAPTURE_DIR'];
    Future<void> settleWindow() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      if (output == null) return;
      await Directory(output).create(recursive: true);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    final states = <Map<String, Object?>>[];
    try {
      await windowManager.maximize();
      await settleWindow();
      expect(await windowManager.isMaximized(), isTrue);
      final titlebar = tester.getRect(
        find.byKey(const ValueKey('custom-titlebar')),
      );
      expect(titlebar.top, 0);
      expect(titlebar.height, 40);
      final caption = tester.getRect(find.byTooltip(vm.strings.close));
      expect(caption.size, const Size(42, 39));
      await capture('custom-titlebar-maximized');
      final source = vm.editor.text, layout = vm.layout;
      for (var round = 0; round < 3; round++) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey.f5,
          physicalKey: PhysicalKeyboardKey.f5,
        );
        await settleWindow();
        expect(await windowManager.isFullScreen(), isTrue);
        expect(find.byKey(const ValueKey('custom-titlebar')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('presentation-next')));
        await tester.pumpAndSettle();
        expect(vm.presenter!.page, 1);
        if (round == 0) await capture('presentation-markdown');
        await tester.tap(find.byKey(const ValueKey('presentation-map')));
        await tester.pumpAndSettle();
        expect(vm.presenter!.map.selectedId, 'slide-1');
        if (round == 0) await capture('presentation-mindmap');
        await tester.sendKeyEvent(
          LogicalKeyboardKey.arrowRight,
          physicalKey: PhysicalKeyboardKey.arrowRight,
        );
        await tester.pumpAndSettle();
        expect(vm.presenter!.page, 2);
        await tester.sendKeyEvent(
          LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
        );
        await settleWindow();
        expect(await windowManager.isFullScreen(), isFalse);
        expect(await windowManager.isMaximized(), isTrue);
        expect(find.byKey(const ValueKey('custom-titlebar')), findsOneWidget);
        expect(vm.layout, layout);
        expect(vm.editor.text, source);
        expect(vm.editor.session.isDirty, isFalse);
        expect(tester.takeException(), isNull);
        states.add({
          'round': round + 1,
          'fullscreenEntered': true,
          'maximizedRestored': true,
          'sourceUnchanged': true,
        });
      }
      // Restore from a normal window as well as from a maximized one.
      await windowManager.unmaximize();
      await settleWindow();
      final normal = await windowManager.getBounds();
      await tester.sendKeyEvent(
        LogicalKeyboardKey.f5,
        physicalKey: PhysicalKeyboardKey.f5,
      );
      await settleWindow();
      expect(await windowManager.isFullScreen(), isTrue);
      await tester.tap(find.byKey(const ValueKey('presentation-exit')));
      await settleWindow();
      expect(await windowManager.isFullScreen(), isFalse);
      expect(await windowManager.isMaximized(), isFalse);
      final restored = await windowManager.getBounds();
      expect(restored.width, closeTo(normal.width, 1));
      expect(restored.height, closeTo(normal.height, 1));
      expect(restored.left, closeTo(normal.left, 1));
      expect(restored.top, closeTo(normal.top, 1));
      if (output != null) {
        await File('$output/window-states.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'titlebar': {
              'top': titlebar.top,
              'height': titlebar.height,
              'type': 'custom',
              'captionWidth': caption.width,
              'captionHeight': caption.height,
            },
            'maximizedRounds': states,
            'normalBoundsRestored': true,
          }),
        );
      }
    } finally {
      await windowManager.setFullScreen(false);
      await windowManager.setPreventClose(false);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }
  });
}
