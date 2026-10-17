import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/data/services/desktop_window.dart';
import 'package:texweft/data/services/export_service.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Mermaid desktop/phone previews, editing and exports', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    vm.sidebar = false;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TexweftApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await windowManager.show();
    await tester.pumpAndSettle();
    final directory = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    Future<void> capture(String name) async {
      if (directory == null) return;
      await Directory(directory).create(recursive: true);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$directory/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }

    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      for (var adjustment = 0; adjustment < 3; adjustment++) {
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
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: theme);
        for (final template in MermaidTemplate.values) {
          vm.editor.session.replace('# ${template.zh}${template.markdown}');
          await tester.pumpAndSettle();
          expect(find.byType(MarkdownMermaidBlock), findsOneWidget);
          expect(
            find.byKey(const ValueKey('mermaid-error')),
            findsNothing,
            reason: '${template.name} ${size.width} ${theme.name}',
          );
          expect(tester.takeException(), isNull);
          await capture('${size.width.toInt()}-${theme.name}-${template.name}');
        }
        vm.editor.session.replace(MermaidTemplate.flowchart.markdown);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('mermaid-preview')));
        await tester.pumpAndSettle();
        await capture('${size.width.toInt()}-${theme.name}-expanded');
        expect(tester.takeException(), isNull);
      }
    }

    if (directory != null) {
      final service = DocumentExportService();
      final source = MermaidTemplate.values
          .map((t) => '## ${t.zh}${t.markdown}')
          .join();
      final colors = Theme.of(tester.element(find.byType(Scaffold).first))
          .colorScheme;
      await File('$directory/mermaid.pdf').writeAsBytes(
        await service.pdf(
          source: source,
          title: 'Mermaid',
          colors: colors,
          typography: MarkdownTypography.simple,
        ),
      );
      await File('$directory/mermaid.docx')
          .writeAsBytes(await service.docx(source: source, title: 'Mermaid'));
      await File('$directory/mermaid.html').writeAsString(
        await service.html(
          source: source,
          title: 'Mermaid',
          colors: colors,
          typography: MarkdownTypography.simple,
        ),
      );
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
