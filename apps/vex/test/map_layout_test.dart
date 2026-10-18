import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/ui/workspace/workspace_dialogs.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';
import 'package:vex/l10n/l10n.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import 'support/fakes.dart';

void main() {
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
