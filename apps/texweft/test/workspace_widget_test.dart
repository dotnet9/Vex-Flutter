import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/domain/workspace.dart';
import 'package:texweft/ui/workspace/workspace_dialogs.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'all eight desktop layouts render without overflow in both themes',
    (tester) async {
      final vm = fakeWorkspace();
      await tester.binding.setSurfaceSize(const Size(980, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(TexweftApp(viewModel: vm));
      await tester.pumpAndSettle();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: mode);
        await tester.pumpAndSettle();
        for (final layout in WorkspaceLayout.values) {
          vm.setLayout(layout);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${mode.name}/${layout.name}',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
  testWidgets('phone navigation and appearance dialog fit a narrow display', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(TexweftApp(viewModel: vm));
    await tester.pumpAndSettle();
    expect(find.text('写作'), findsOneWidget);
    await tester.tap(find.text('导图'));
    await tester.pumpAndSettle();
    expect(vm.layout, WorkspaceLayout.map);
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(Scaffold).first);
    final dialog = showAppearance(context, vm);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await dialog;
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
