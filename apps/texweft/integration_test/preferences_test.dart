import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/data/services/desktop_window.dart';
import 'package:texweft/ui/workspace/preferences_dialog.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native preference geometry and desktop/phone screenshots', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
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
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Scaffold).first);
        final shown = showPreferences(context, vm);
        await tester.pumpAndSettle();
        final dialog = find.byKey(const ValueKey('preferences-dialog'));
        expect(
          tester.getSize(dialog).width,
          size.width < 650 ? closeTo(size.width, 2) : 675,
        );
        for (final category in PreferenceCategory.values) {
          await tester.tap(
            find.byKey(ValueKey('preference-category-${category.name}')),
          );
          await tester.pumpAndSettle();
          if (category == PreferenceCategory.general) {
            final header = tester.getRect(
              find.byKey(const ValueKey('preferences-header')),
            );
            final field = tester.getRect(
              find.byType(DropdownButtonFormField<String>).first,
            );
            expect(field.top - header.bottom, lessThan(40));
          }
          await capture('${size.width.toInt()}-${theme.name}-${category.name}');
          if (category == PreferenceCategory.appearance) {
            final scroll = find.byKey(const ValueKey('preferences-scroll'));
            await tester.drag(scroll, const Offset(0, -500));
            await tester.pumpAndSettle();
            await capture('${size.width.toInt()}-${theme.name}-watermark');
          }
          expect(tester.takeException(), isNull, reason: category.name);
          if (size.width < 650) {
            await tester.tap(find.byTooltip(vm.strings.prefBack));
            await tester.pumpAndSettle();
          }
        }
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        await shown;
      }
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
