import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/data/services/update_download_service.dart';
import 'package:vex/data/services/update_service.dart';
import 'package:vex/ui/workspace/update_dialog.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';
import '../test/support/update_fixture.dart';

class _PausedDownload extends UpdateDownloader {
  final result = Completer<VerifiedUpdate>();
  @override
  Future<VerifiedUpdate> download(
    UpdatePackage package, {
    required UpdateCancellation cancellation,
    void Function(UpdateProgress)? onProgress,
  }) {
    onProgress?.call(const UpdateProgress(28, 100));
    return result.future;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native update progress and ready layouts remain readable', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final fixture = await UpdateFixture.create();
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();
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
      for (final size in [const Size(1280, 900), const Size(390, 844)]) {
        for (var i = 0; i < 3; i++) {
          final actual =
              tester.view.physicalSize / tester.view.devicePixelRatio;
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
          final verified = await fixture.download(),
              downloader = _PausedDownload();
          unawaited(
            showUpdateDownload(
              tester.element(find.byType(Scaffold).first),
              tag: 'v9.0.0',
              package: fixture.package,
              downloader: downloader,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('update-primary')));
          await tester.pumpAndSettle();
          expect(find.text('28%'), findsOneWidget);
          await capture('${size.width.toInt()}-${mode.name}-progress');
          downloader.result.complete(verified);
          await tester.pumpAndSettle();
          expect(find.text(vm.strings.updateVerified), findsOneWidget);
          await capture('${size.width.toInt()}-${mode.name}-ready');
          await tester.tap(find.text(vm.strings.cancel));
          await tester.pumpAndSettle();
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      await fixture.close();
    }
  });
}
