import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/data/services/desktop_window.dart';
import 'package:texweft/data/services/export_service.dart';
import 'package:texweft/domain/workspace.dart';
import 'package:texweft/ui/workspace/preferences_dialog.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

const sample = r'''# 数学与化学

面积 $A=\pi r^2$，能量 $E=mc^2$，方程 $ax^2+bx+c=0$。

==重要结论==　水 H~2~O，平方 x^2^，离子 $\ce{SO4^{2-}}$。

## 求根公式

$$
x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}
$$

## 积分与矩阵

$$
\int_{-\infty}^{+\infty}e^{-x^2}\,dx=\sqrt{\pi}
$$

$$
\mathbf{A}=\begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}
$$

## 化学反应

$$
\ce{2H2 + O2 -> 2H2O}
$$

$$
\ce{N2 + 3H2 <=> 2NH3}
$$

水分子 $\ce{H2O}$。
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Markdown math, mobile settings and offline exports', (
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
      expect(tester.takeException(), isNull, reason: name);
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
        vm.editor.session.replace(sample);
        vm.setLayout(WorkspaceLayout.read);
        await tester.pumpAndSettle();
        await capture('${size.width.toInt()}-${theme.name}-read');
        vm.setLayout(WorkspaceLayout.instant);
        vm.editor.session.replace('\$\$\n\\ce{N2 + 3H2 <=> 2NH3}\n\$\$');
        await tester.pumpAndSettle();
        await tester.tap(find.byType(MarkdownMathFormula));
        await tester.pumpAndSettle();
        await capture('${size.width.toInt()}-${theme.name}-editing');
        final scaffold = tester.element(find.byType(Scaffold).first);
        showPreferences(scaffold, vm, category: PreferenceCategory.markdown);
        await tester.pumpAndSettle();
        await capture('${size.width.toInt()}-${theme.name}-preferences');
        await tester.tap(find.text(vm.strings.done));
        await tester.pumpAndSettle();
      }
    }
    if (directory != null) {
      final service = DocumentExportService();
      final colors = Theme.of(tester.element(find.byType(Scaffold).first))
          .colorScheme;
      await File('$directory/formulas.html').writeAsString(
        await service.html(
          source: sample,
          title: '数学与化学',
          colors: colors,
          typography: MarkdownTypography.simple,
        ),
      );
      await File('$directory/formulas.pdf').writeAsBytes(
        await service.pdf(
          source: sample,
          title: '数学与化学',
          colors: colors,
          typography: MarkdownTypography.simple,
        ),
      );
      await File('$directory/formulas.docx')
          .writeAsBytes(await service.docx(source: sample, title: '数学与化学'));
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
