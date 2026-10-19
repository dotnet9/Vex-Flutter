import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/l10n/l10n.dart';
import 'package:vex/ui/core/app_widgets.dart';
import 'package:vex/ui/workspace/workspace_guide.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';

import 'support/fakes.dart';

void main() {
  test('adaptive projection preserves the requested desktop arrangement', () {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.setLayout(WorkspaceLayout.three);
    vm.viewport = WorkspaceViewport.phone;
    expect(vm.layout, WorkspaceLayout.source);
    vm.persist();
    expect((vm.settings as MemorySettings).value['layout'], 'three');
    vm.viewport = WorkspaceViewport.tablet;
    expect(vm.layout, WorkspaceLayout.sourceRender);
    vm.viewport = WorkspaceViewport.desktop;
    expect(vm.layout, WorkspaceLayout.three);
  });

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    testWidgets('restored layouts, find, picker and guide adapt to $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      (vm.settings as MemorySettings).value = {'layout': 'three'};
      await vm.initialize(watchFiles: false);
      vm.editor.session.replace('# Original\n\nneedle\n\n## End\n\nLast line');
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final phone = size.shortestSide < 600;
      final limit = phone ? 1 : 2;
      expect(vm.layout.panes.length, limit);
      expect(
        find.byType(ResizableSplit),
        phone ? findsNothing : findsOneWidget,
      );
      if (phone) {
        expect(find.byTooltip('工作区布局'), findsNothing);
      } else {
        await tester.tap(find.byTooltip('工作区布局'));
        await tester.pumpAndSettle();
        for (final layout in WorkspaceLayout.values) {
          expect(
            find.byKey(ValueKey('layout-${layout.name}')),
            layout.panes.length <= limit ? findsOneWidget : findsNothing,
          );
        }
        await tester.tap(find.byTooltip(vm.strings.closePicker));
        await tester.pumpAndSettle();
      }
      vm.setLayout(WorkspaceLayout.read);
      vm.search('needle');
      vm.nextMatch();
      await tester.pumpAndSettle();
      expect(vm.layout.panes.length, limit);
      expect(vm.layout.panes, contains('source'));
      final before = vm.editor.text;
      vm.startGuide();
      for (var step = 0; step < 8; step++) {
        vm.advanceGuide(step);
        await tester.pumpAndSettle();
        expect(vm.layout.panes.length, lessThanOrEqualTo(limit));
        expect(find.byKey(const ValueKey('guide-pointer')), findsOneWidget);
        expect(find.byKey(const ValueKey('guide-arrow')), findsNothing);
        final card = tester.getRect(
          find
              .descendant(
                of: find.byType(WorkspaceGuide),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(size.width));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull, reason: 'guide $step');
      }
      vm.endGuide();
      await tester.pumpAndSettle();
      expect(vm.editor.text, before);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
  }

  testWidgets('window resize restores desktop panes without losing edits', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final vm = fakeWorkspace();
    vm.setLayout(WorkspaceLayout.three);
    vm.editor.session.replace('# Preserve edits');
    for (final width in [1280.0, 390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      expect(vm.layout.panes.length, width < 700 ? 1 : 3);
      expect(vm.editor.text, '# Preserve edits');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('dialog footer stays right-aligned while only its body scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AppDialog(
                  title: 'Fixed title',
                  actions: [
                    TextButton(onPressed: () {}, child: const Text('Apply')),
                  ],
                  child: Text(List.filled(80, 'Body line').join('\n')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final title = tester.getRect(find.byKey(const ValueKey('dialog-titlebar')));
    final footer = tester.getRect(find.text('Apply'));
    final dialog = tester.getRect(find.byType(Dialog));
    expect(footer.center.dx, greaterThan(dialog.center.dx));
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('dialog-titlebar'))),
      title,
    );
    expect(tester.getRect(find.text('Apply')), footer);
    expect(tester.takeException(), isNull);
  });
}
