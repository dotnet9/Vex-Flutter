import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('narrow desktop menus never push window controls off screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const channel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isMaximized' ? false : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final vm = fakeWorkspace();
    var collapsed = false;
    for (final language in ['zh', 'en', 'ja', 'zh_Hant']) {
      vm.updateAppearance(language: language);
      for (final width in [800.0, 900.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(VexApp(viewModel: vm, windowIntegration: true));
        await tester.pumpAndSettle();
        final header = tester.getRect(
          find.byKey(const ValueKey('custom-titlebar')),
        );
        final close = tester.getRect(find.byTooltip(vm.strings.close));
        expect(close.right, closeTo(header.right, .1));
        expect(close.left, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull, reason: '$language $width');
        final overflow = find.byKey(const ValueKey('titlebar-overflow'));
        if (overflow.evaluate().isNotEmpty) {
          collapsed = true;
          await tester.tap(overflow);
          await tester.pumpAndSettle();
          for (final id in [
            'file',
            'edit',
            'paragraph',
            'format',
            'view',
            'tools',
            'help',
          ]) {
            expect(find.byKey(ValueKey('compact-menu-$id')), findsOneWidget);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('menu-open')), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    }
    expect(collapsed, isTrue);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
