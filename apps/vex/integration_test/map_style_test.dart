import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/data/services/export_service.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native six map styles and exported images stay consistent', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    vm.editor.session.replace(
      '# 想法成形\n\n## 收集\n\n### 记录灵感\n\n## 梳理\n\n### 连接线索\n\n## 表达\n\n### 写成文章\n',
    );
    vm.editor.session.markSaved();
    vm.setLayout(WorkspaceLayout.map);
    vm.map.setMode(MindMapLayoutMode.balanced);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();
    final source = vm.editor.text,
        transform = vm.map.transformation.value.clone();
    try {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: mode);
        for (final style in MindMapStyle.values) {
          vm.setMapStyle(style);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(vm.editor.text, source);
          expect(vm.editor.session.isDirty, isFalse);
          expect(vm.map.transformation.value, transform);
          final directory = Platform.environment['VEX_CAPTURE_DIR'];
          if (directory == null) continue;
          await Directory(directory).create(recursive: true);
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$directory/${mode.name}-${style.name}-app.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
          final theme = Theme.of(tester.element(find.byType(MindMapView)));
          final png = await DocumentExportService().mindMapPng(
            vm.map.root,
            theme.colorScheme,
            layout: vm.map.layout,
            style: vm.map.style,
            textStyle: theme.textTheme.bodyMedium ?? const TextStyle(),
          );
          await File('$directory/${mode.name}-${style.name}-export.png')
              .writeAsBytes(png);
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }
  });
}
