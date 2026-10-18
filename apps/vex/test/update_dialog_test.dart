import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/update_service.dart';
import 'package:vex/ui/workspace/workspace_dialogs.dart';

import 'support/fakes.dart';

class _Checker implements UpdateChecker {
  Future<UpdateCheckResult> Function(String?) action = (_) async =>
      const UpdateCheckResult(UpdateStatus.current);
  bool closed = false;
  @override
  Future<UpdateCheckResult> check(String? version) => action(version);
  @override
  void close() => closed = true;
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Vex',
      packageName: 'com.codewf.vex',
      version: '0.3.1',
      buildNumber: '6',
      buildSignature: '',
    );
  });

  testWidgets('update check disables duplicate checks and recovers for retry', (
    tester,
  ) async {
    final vm = fakeWorkspace(), checker = _Checker();
    final pending = Completer<UpdateCheckResult>();
    checker.action = (version) {
      expect(version, '0.3.1');
      return pending.future;
    };
    await tester.pumpWidget(VexApp(viewModel: vm));
    unawaited(
      showAbout(tester.element(find.byType(Scaffold).first), updates: checker),
    );
    await tester.pumpAndSettle();
    final check = find.byKey(const ValueKey('about-check-updates'));
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(
            find.descendant(of: check, matching: find.byType(TextButton)),
          )
          .onPressed,
      isNull,
    );
    pending.complete(
      const UpdateCheckResult(UpdateStatus.available, tag: 'v0.4.0'),
    );
    await tester.pumpAndSettle();
    expect(find.text(vm.strings.updateAvailable('v0.4.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('about-open-release')), findsOneWidget);
    checker.action = (_) async => throw const UpdateHttpException(403);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(find.text(vm.strings.updateHttpError(403)), findsOneWidget);
    checker.action = (_) async => const UpdateCheckResult(UpdateStatus.current);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(find.text(vm.strings.updateCurrent), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(checker.closed, isTrue);
    vm.dispose();
  });

  testWidgets(
    'closing about while checking disposes the request without errors',
    (tester) async {
      final vm = fakeWorkspace(), checker = _Checker();
      final pending = Completer<UpdateCheckResult>();
      checker.action = (_) => pending.future;
      await tester.pumpWidget(VexApp(viewModel: vm));
      unawaited(
        showAbout(
          tester.element(find.byType(Scaffold).first),
          updates: checker,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('about-check-updates')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(checker.closed, isTrue);
      pending.completeError(StateError('request aborted'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
