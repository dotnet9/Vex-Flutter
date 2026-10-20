import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/repositories/credential_repository.dart';
import 'package:vex/ui/workspace/preference_controls.dart';
import 'package:vex/ui/workspace/preferences_dialog.dart';
import 'package:vex/ui/workspace/workspace_mcp.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

McpPreferences preferences(
  WorkspaceMcp mcp, {
  bool? enabled,
  int? port,
  String? token,
}) => (
  enabled: enabled ?? mcp.enabled,
  port: port ?? mcp.port,
  token: token ?? mcp.token,
  scope: mcp.scope,
  folder: mcp.customFolder,
  confirmation: mcp.requireConfirmation,
);

final class DelayedCredentials implements CredentialRepository {
  final entered = Completer<void>(), release = Completer<void>();
  String? token;
  @override
  Future<String?> readMcpToken() async => token;
  @override
  Future<void> writeMcpToken(String value) async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    token = value;
  }
}

void main() {
  group('backend', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test(
      'disabled settings and regenerated token survive a workspace reload',
      () async {
        final vm = fakeWorkspace();
        addTearDown(vm.dispose);
        final token = 'new-token-for-disabled-service-123';
        vm.mcp.updatePreferences(
          preferences(vm.mcp, port: 18901, token: token),
        );
        await vm.finishPendingSaves();
        expect(vm.mcp.settingsSaving, isFalse);
        expect(vm.mcp.server.running, isFalse);
        expect((vm.mcp.credentials as MemoryCredentials).token, token);
        final next = WorkspaceViewModel(
          credentials: vm.mcp.credentials,
          files: MemoryFiles(),
          settings: vm.settings,
          recovery: MemoryRecovery(),
        );
        addTearDown(next.dispose);
        await next.initialize(watchFiles: false);
        expect(next.mcp.token, token);
        expect(next.mcp.port, 18901);
        expect(next.mcp.enabled, isFalse);
      },
    );

    test(
      'stop invalidates an in-flight start before credential storage returns',
      () async {
        final credentials = DelayedCredentials();
        final vm = WorkspaceViewModel(
          credentials: credentials,
          files: MemoryFiles(),
          settings: MemorySettings(),
          recovery: MemoryRecovery(),
        );
        addTearDown(vm.dispose);
        final starting = vm.mcp.configure(true);
        await credentials.entered.future;
        vm.mcp.updatePreferences(
          preferences(vm.mcp, enabled: false),
          immediate: true,
        );
        credentials.release.complete();
        await starting;
        await vm.mcp.flushSettings();
        expect(vm.mcp.enabled, isFalse);
        expect(vm.mcp.server.running, isFalse);
        expect(vm.mcp.configuring, isFalse);
      },
    );

    test(
      'invalid input preserves configuration but never prevents stopping',
      () async {
        final vm = fakeWorkspace();
        addTearDown(vm.dispose);
        vm.mcp.port = 0;
        await vm.mcp.configure(true);
        expect(vm.mcp.server.running, isTrue);
        vm.mcp.updatePreferences(preferences(vm.mcp, port: 99));
        await vm.mcp.flushSettings();
        expect(vm.mcp.port, 0);
        expect(vm.mcp.server.running, isTrue);
        expect(vm.mcp.settingsError, isNotEmpty);
        await vm.mcp.stopFromSettings(validationError: vm.strings.mcpInvalid);
        expect(vm.mcp.enabled, isFalse);
        expect(vm.mcp.server.running, isFalse);
      },
    );
  });

  testWidgets(
    'switch starts and stops, status stays under switch, closing saves inputs',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      final boundary = GlobalKey();
      final output = Platform.environment['VEX_VISUAL_OUTPUT'];
      if (output != null) {
        await tester.runAsync(() async {
          for (final (family, font) in [
            ('Ahem', 'msyh.ttc'),
            ('Roboto', 'msyh.ttc'),
            ('Segoe UI', 'segoeui.ttf'),
            ('Microsoft YaHei UI', 'msyh.ttc'),
            ('SimSun', 'simsun.ttc'),
          ]) {
            await (FontLoader(family)..addFont(
                  Future.value(
                    ByteData.sublistView(
                      await File('C:/Windows/Fonts/$font').readAsBytes(),
                    ),
                  ),
                ))
                .load();
          }
          await Directory(output).create(recursive: true);
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: VexApp(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> open() async {
        showPreferences(
          tester.element(find.byType(Scaffold).first),
          vm,
          category: PreferenceCategory.mcp,
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        if (output == null) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/mcp-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await open();
      expect(find.text(vm.strings.prefApply), findsNothing);
      expect(find.text(vm.strings.prefMcpStop), findsNothing);
      final toggle = find.byKey(const ValueKey('mcp-enabled'));
      expect(
        tester.getRect(find.text(vm.strings.mcpStopped)).top,
        greaterThanOrEqualTo(tester.getRect(toggle).bottom),
      );
      await capture('stopped');
      final port = (await tester.runAsync(() async {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        socket.listen((client) => client.destroy());
        final port = socket.port;
        await socket.close();
        return port;
      }))!;
      final portField = find.descendant(
        of: find.byKey(const ValueKey('mcp-port')),
        matching: find.byType(TextField),
      );
      await tester.enterText(portField, '$port');
      await tester.tap(find.text(vm.strings.done));
      await tester.pumpAndSettle();
      await vm.finishPendingSaves();
      expect(vm.mcp.port, port);
      await open();
      await tester.runAsync(() async {
        tester.widget<PreferenceSwitch>(toggle).onChanged!(
          !tester.widget<PreferenceSwitch>(toggle).value,
        );
        await vm.mcp.flushSettings().timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(vm.mcp.server.running, isTrue);
      expect(find.textContaining(vm.mcp.server.endpoint!), findsOneWidget);
      await capture('running');
      await tester.enterText(portField, '99');
      await tester.pump();
      expect(vm.mcp.port, port);
      await tester.runAsync(() async {
        tester.widget<PreferenceSwitch>(toggle).onChanged!(
          !tester.widget<PreferenceSwitch>(toggle).value,
        );
        await vm.mcp.flushSettings().timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(vm.mcp.server.running, isFalse);
      expect(tester.widget<PreferenceSwitch>(toggle).value, isFalse);
      // An occupied port leaves the switch off and presents the failure locally.
      final occupied = await tester.runAsync(() async {
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        socket.listen((client) => client.destroy());
        return socket;
      });
      await tester.enterText(portField, '$port');
      await tester.runAsync(() async {
        tester.widget<PreferenceSwitch>(toggle).onChanged!(
          !tester.widget<PreferenceSwitch>(toggle).value,
        );
        await vm.mcp.flushSettings().timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(vm.mcp.server.running, isFalse);
      expect(tester.widget<PreferenceSwitch>(toggle).value, isFalse);
      expect(find.text(vm.strings.prefMcpStartFailed), findsWidgets);
      await capture('failure');
      await tester.runAsync(occupied!.close);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
