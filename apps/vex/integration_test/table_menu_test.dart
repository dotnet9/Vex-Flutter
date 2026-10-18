import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native table flyouts, alignment and compact touch menu', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    const source =
        '# 表格操作\n\n| 名称 | 进度 |\n| --- | --- |\n'
        '| **原型** | `已确认` |\n| 功能实现 | 进行中 |\n';
    vm.editor.session.replace(source);
    vm.editor.session.markSaved();
    vm.setLayout(WorkspaceLayout.instant);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();
    final directory = Platform.environment['VEX_CAPTURE_DIR'];
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
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('table-display-1-0')), findsOneWidget);
        await capture('${size.width.toInt()}-${mode.name}-table-rich-cells');
        final cell = find.byKey(const ValueKey('table-cell-1-1'));
        await tester.tap(cell, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        await capture('${size.width.toInt()}-${mode.name}-table-context');
        final key = size.width > 700 ? 'menu' : 'touch-menu';
        final align = find.byKey(ValueKey('$key-table:alignRight'));
        if (size.width < 700) {
          await tester.scrollUntilVisible(
            align,
            180,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('touch-workspace-menu')),
              matching: find.byType(Scrollable),
            ),
          );
        }
        await tester.tap(align);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(cell).textAlign, TextAlign.right);
        await capture('${size.width.toInt()}-${mode.name}-table-aligned');
        vm.editor.session.undo();
        await tester.pumpAndSettle();
        expect(vm.editor.text, source);
        if (size.width > 700) {
          vm.editor.select(source.indexOf('已确认'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('段落(P)'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('menu-table')));
          await tester.pumpAndSettle();
          await capture('1280-${mode.name}-table-submenu');
          await tester.tap(find.byKey(const ValueKey('menu-table:rowBelow')));
          await tester.pumpAndSettle();
          expect(vm.editor.tableTarget()!.table.rows, hasLength(4));
          vm.editor.session.undo();
          await tester.pumpAndSettle();
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
