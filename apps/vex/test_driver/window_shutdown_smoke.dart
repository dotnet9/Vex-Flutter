// Build this entrypoint in Release and launch the executable directly. The
// expected result is a clean native process exit, which disconnects a driver.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/repositories/recovery_repository.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import '../test/support/fakes.dart';

class _Recovery implements RecoveryRepository {
  _Recovery(this.output, this.mode);
  final String output, mode;
  bool armed = false, cancelVerified = false;

  @override
  Future<List<Map<String, Object?>>> load() async => [];

  @override
  Future<void> save(List<Map<String, Object?>> documents) async {
    if (!armed) return;
    await File(output).writeAsString(
      jsonEncode({
        'mode': mode,
        'recoveryFlushed': true,
        'cancelVerified': cancelVerified,
        'documents': documents,
      }),
      flush: true,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('release native shutdown with a mounted source editor', (
    tester,
  ) async {
    final output = Platform.environment['VEX_CLOSE_RESULT'];
    final mode = Platform.environment['VEX_CLOSE_MODE'];
    if (output == null || !['clean', 'draft'].contains(mode)) {
      stderr.writeln('Set VEX_CLOSE_RESULT and VEX_CLOSE_MODE.');
      exit(1);
    }
    // A failed close must produce a nonzero process result, never hang a probe.
    Timer(const Duration(seconds: 30), () => exit(2));
    try {
      await initializeDesktopWindow();
      final recovery = _Recovery(output, mode!);
      final vm = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: MemorySettings(),
        recovery: recovery,
      );
      await vm.initialize(watchFiles: false);
      vm.setLayout(WorkspaceLayout.source);
      await tester.pumpWidget(VexApp(viewModel: vm, windowIntegration: true));
      await tester.pumpAndSettle();
      if (mode == 'draft') {
        vm.editor.session.replace('# Release 关闭草稿🧵\r\n保留内容\n');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(vm.strings.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text(vm.strings.cancel));
        await tester.pumpAndSettle();
        expect(vm.editor.session.isDirty, isTrue);
        expect(find.text(vm.strings.keepDraftClose), findsNothing);
        recovery.cancelVerified = true;
      }
      recovery.armed = true;
      await tester.tap(find.byTooltip(vm.strings.close));
      await tester.pumpAndSettle();
      if (mode == 'draft') {
        await tester.tap(find.text(vm.strings.keepDraftClose));
        await tester.pumpAndSettle();
      }
      // The native message loop must now exit. Do not exit(0) from Dart: that
      // would bypass the engine/COM teardown that this probe is checking.
    } catch (error, stack) {
      await File('$output.error').writeAsString('$error\n$stack');
      exit(1);
    }
  });
}
