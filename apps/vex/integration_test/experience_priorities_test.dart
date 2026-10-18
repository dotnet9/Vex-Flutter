import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/core/app_widgets.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native reading margins and keyboard focus across sizes', (
    tester,
  ) async {
    final output = Platform.environment['VEX_CAPTURE_DIR'];
    expect(
      output,
      isNotNull,
      reason: 'Set VEX_CAPTURE_DIR for native screenshots.',
    );
    await Directory(output!).create(recursive: true);
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace();
    await vm.initialize(watchFiles: false);
    const source =
        '# 写下想法，看见脉络\n\n'
        '从一个清晰的想法开始。保存正文时，正在输入的候选保持原样。\n\n'
        '## 留一点阅读空间\n\n'
        '手机上的写作与预览使用相同边距；桌面分栏保留安静、整齐的正文。\n\n'
        '- 文件留在本地\n- 内容可以撤销\n- 导图按需展开\n\n'
        '```dart\nfinal thought = "维刻 Vex";\nprint(thought);\n```\n';
    vm.editor.session.replace(source);
    vm.editor.session.markSaved();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> resize(Size size) async {
      for (var attempt = 0; attempt < 3; attempt++) {
        final client = tester.view.physicalSize / tester.view.devicePixelRatio;
        final outer = await windowManager.getSize();
        await windowManager.setSize(
          Size(
            outer.width + size.width - client.width,
            outer.height + size.height - client.height,
          ),
        );
        await tester.pumpAndSettle();
      }
      final actual = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(actual.width, closeTo(size.width, 2));
      expect(actual.height, closeTo(size.height, 2));
    }

    Future<void> capture(String name) async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      try {
        final pixels = (await image.toByteData())!.buffer.asUint32List();
        expect(pixels.toSet().length, greaterThan(50), reason: name);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/$name.png').writeAsBytes(png!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
      expect(tester.takeException(), isNull, reason: name);
    }

    for (final size in [
      const Size(1280, 900),
      const Size(390, 844),
      const Size(320, 740),
    ]) {
      await resize(size);
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: theme, fontSize: 24, motion: false);
        for (final layout in [WorkspaceLayout.instant, WorkspaceLayout.read]) {
          vm.setLayout(layout);
          await tester.pumpAndSettle();
          final list = tester.widget<SuperListView>(
            find.descendant(
              of: find.byType(WorkspacePanes),
              matching: find.byType(SuperListView),
            ),
          );
          expect(
            list.padding!.resolve(TextDirection.ltr).left,
            size.width < 700 ? 25 : 44,
          );
          await capture('${size.width.toInt()}-${theme.name}-${layout.name}');
        }
        if (size.width >= 700) {
          final close = find
              .descendant(
                of: find.byKey(const ValueKey('custom-titlebar')),
                matching: find.byType(AppCaptionButton),
              )
              .last;
          final glyph = find.descendant(
            of: close,
            matching: find.byType(AppGlyph),
          );
          Focus.of(tester.element(glyph)).requestFocus();
          await tester.pumpAndSettle();
          expect(Focus.of(tester.element(glyph)).hasFocus, isTrue);
          expect(tester.getSize(close), const Size(46, 32));
          await capture('1280-${theme.name}-caption-focus');
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(Focus.of(tester.element(glyph)).hasFocus, isFalse);
        }
      }
    }
    expect(vm.editor.session.text, source);
    expect(vm.editor.session.isDirty, isFalse);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
