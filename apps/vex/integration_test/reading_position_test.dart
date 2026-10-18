import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native appearance changes keep the reading paragraph', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    vm.editor.session.replace(
      List.generate(
        120,
        (i) =>
            '## 第 $i 节\n\n${List.filled(35, '写下想法，看见脉络。Reading stays here.').join(' ')}\n',
      ).join('\n'),
    );
    vm.editor.session.markSaved();
    final source = vm.editor.text;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      final directory = Platform.environment['VEX_CAPTURE_DIR'];
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

    try {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final layout in [WorkspaceLayout.read, WorkspaceLayout.instant]) {
          vm.updateAppearance(
            mode: mode,
            typography: MarkdownTypography.simple,
            fontSize: 16,
          );
          vm.setLayout(layout);
          await tester.pumpAndSettle();
          final view = tester.widget<SuperListView>(
            find.byType(SuperListView).last,
          );
          final list = view.listController!, scroll = view.controller!;
          list.jumpToItem(index: 121, scrollController: scroll, alignment: 0);
          await tester.pumpAndSettle();
          scroll.jumpTo(scroll.offset + 30);
          await tester.pumpAndSettle();
          final visible = list.visibleRange!.$1;
          await capture('${mode.name}-${layout.name}-before');
          vm.updateAppearance(
            typography: MarkdownTypography.column,
            fontSize: 24,
          );
          await tester.pump();
          expect(list.visibleRange!.$1, visible);
          await tester.pumpAndSettle();
          expect(list.visibleRange!.$1, visible);
          expect(vm.editor.text, source);
          expect(vm.editor.session.isDirty, isFalse);
          await capture('${mode.name}-${layout.name}-after');
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }
  });
}
