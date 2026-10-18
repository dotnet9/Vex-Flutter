import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/update_download_service.dart';
import 'package:vex/data/services/update_install_service.dart';
import 'package:vex/data/services/update_service.dart';
import 'package:vex/ui/workspace/update_dialog.dart';

import 'support/fakes.dart';
import 'support/update_fixture.dart';

class _Downloader extends UpdateDownloader {
  late Future<VerifiedUpdate> Function(
    UpdateCancellation,
    void Function(UpdateProgress)?,
  )
  action;
  @override
  Future<VerifiedUpdate> download(
    UpdatePackage package, {
    required UpdateCancellation cancellation,
    void Function(UpdateProgress)? onProgress,
  }) => action(cancellation, onProgress);
}

class _Installer implements UpdateInstaller {
  bool launched = false;
  bool cancel = false;
  @override
  Future<bool> install(
    VerifiedUpdate update, {
    UpdateClose? closeWorkspace,
  }) async {
    launched = true;
    return !cancel;
  }
}

class _NetworkOverrides extends HttpOverrides {}

void main() {
  late UpdateFixture fixture;
  late VerifiedUpdate verified;
  setUp(
    () => HttpOverrides.runWithHttpOverrides(() async {
      fixture = await UpdateFixture.create();
      verified = await fixture.download();
    }, _NetworkOverrides()),
  );
  tearDown(() async => fixture.close());

  for (final width in [390.0, 1280.0]) {
    testWidgets('download retry, verified install and cancel fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final vm = fakeWorkspace();
      await tester.pumpWidget(VexApp(viewModel: vm));
      final installer = _Installer()..cancel = true;
      final downloader = _Downloader();
      var attempt = 0;
      downloader.action = (_, _) async {
        if (attempt++ == 0) throw const UpdateIntegrityException();
        return verified;
      };
      unawaited(
        showUpdateDownload(
          tester.element(find.byType(Scaffold).first),
          tag: 'v9.0.0',
          package: fixture.package,
          downloader: downloader,
          installer: installer,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(vm.strings.updateDownloadPrompt), findsOneWidget);
      final primary = find.byKey(const ValueKey('update-primary'));
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.text(vm.strings.updateIntegrityError), findsOneWidget);
      expect(installer.launched, isFalse);
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.text(vm.strings.updateVerified), findsOneWidget);
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(installer.launched, isTrue);
      expect(find.text(vm.strings.updateVerified), findsOneWidget);
      installer.cancel = false;
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-primary')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
  }

  testWidgets(
    'closing a download cancels without installing or mutating the document',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final vm = fakeWorkspace();
      final original = vm.editor.text;
      final downloader = _Downloader(), installer = _Installer();
      final pending = Completer<VerifiedUpdate>();
      late UpdateCancellation cancellation;
      downloader.action = (value, progress) {
        cancellation = value;
        progress?.call(const UpdateProgress(256, 1024));
        return pending.future;
      };
      await tester.pumpWidget(VexApp(viewModel: vm));
      unawaited(
        showUpdateDownload(
          tester.element(find.byType(Scaffold).first),
          tag: 'v9.0.0',
          package: fixture.package,
          downloader: downloader,
          installer: installer,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-primary')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-progress')), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, .25);
      expect(
        indicator.backgroundColor,
        isNot(
          Theme.of(tester.element(find.byType(LinearProgressIndicator)))
              .colorScheme
              .primary,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(cancellation.cancelled, isTrue);
      pending.completeError(const UpdateCancelled());
      await tester.pumpAndSettle();
      expect(vm.editor.text, original);
      expect(installer.launched, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
