import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_dialogs.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';
import 'package:vex/l10n/l10n.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import 'support/fakes.dart';

void main() {
  for (final source in ['', '# Root\n\n## Existing\n\nBody']) {
    testWidgets('new map nodes are selected and ready to rename: $source', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      vm.editor.session.replace(source);
      vm.setSummary(paragraphs: false, lists: false, blocks: false);
      vm.setLayout(WorkspaceLayout.map);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final root = find.descendant(
        of: find.byType(MindMapView),
        matching: find.text(vm.map.root.title),
      );
      await tester.tap(root);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('mindmap-inline-title'));
      expect(field, findsOneWidget);
      expect(vm.selectedHeading, isNotNull);
      expect(vm.map.layout.nodes[vm.map.selectedId], isNotNull);
      await tester.enterText(field, 'Created');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        vm.editor.document.headings.map((h) => h.title),
        contains('Created'),
      );
      expect(vm.selectedHeading?.title, 'Created');
      expect(vm.map.layout.nodes[vm.map.selectedId]?.title, 'Created');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      expect(vm.selectedHeading?.parentId, contains('Created'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
  }

  test(
    'map mode persists independently from document order and history',
    () async {
      final settings = MemorySettings();
      final vm = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: settings,
        recovery: MemoryRecovery(),
      );
      await vm.initialize(watchFiles: false);
      vm.editor.session.replace('# Title\n\n## A\n\n## B');
      final text = vm.editor.text, revision = vm.editor.session.revision;
      vm.setSummary(mode: MindMapLayoutMode.balanced);
      expect(settings.value['mapMode'], 'balanced');
      expect(vm.editor.text, text);
      expect(vm.editor.session.revision, revision);
      final restored = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: settings,
        recovery: MemoryRecovery(),
      );
      await restored.initialize(watchFiles: false);
      expect(restored.map.mode, MindMapLayoutMode.balanced);
      vm.dispose();
      restored.dispose();
    },
  );

  for (final size in [const Size(1280, 800), const Size(390, 844)]) {
    testWidgets('all map choices work at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSummarySettings(context, vm),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (final mode in MindMapLayoutMode.values) {
        final choice = find.byKey(ValueKey('map-layout-${mode.name}'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(vm.map.mode, mode);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    });
  }
}
