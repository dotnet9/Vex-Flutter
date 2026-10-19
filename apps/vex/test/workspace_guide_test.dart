import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_guide.dart';
import 'package:vex/ui/workspace/workspace_sidebar.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'desktop guide highlights each guided scene without covering its target',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      await tester.pumpWidget(VexApp(viewModel: vm));
      vm.startGuide();
      for (var step = 0; step < 8; step++) {
        vm.advanceGuide(step);
        await tester.pumpAndSettle();
        final guide = tester.widget<WorkspaceGuide>(
          find.byType(WorkspaceGuide),
        );
        expect(
          guide.target.currentContext,
          isNotNull,
          reason: 'step $step target',
        );
        final target = tester.getRect(find.byKey(guide.target));
        final card = tester.getRect(
          find
              .descendant(
                of: find.byType(WorkspaceGuide),
                matching: find.byType(Material),
              )
              .first,
        );
        if (step == 2) {
          expect(find.byKey(guide.target), findsOneWidget);
          expect(
            find.ancestor(
              of: find.byKey(guide.target),
              matching: find.byType(WorkspaceSidebar),
            ),
            findsOneWidget,
            reason: 'step $step highlights the sidebar outline tab',
          );
          expect(target.width, lessThan(300));
        }
        // 画布幕（开场、导图、正文、排版、演示）的卡片本就覆盖画布，
        // 只有高亮小控件的幕要求卡片避开目标。
        if (step == 1 || step == 2 || step == 7) {
          expect(target.overlaps(card), isFalse, reason: 'step $step');
        }
        if (step == 3) {
          expect(vm.layout, WorkspaceLayout.map, reason: 'step $step');
        }
        if (step == 4) {
          expect(vm.layout, WorkspaceLayout.read, reason: 'step $step');
        }
        expect(tester.takeException(), isNull, reason: 'step $step');
      }
      vm.endGuide();
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceGuide), findsNothing);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    'closing phone guide removes its own sheet but keeps unrelated dialog',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      await tester.pumpWidget(VexApp(viewModel: vm));
      vm.startGuide();
      vm.advanceGuide(5);
      await tester.pumpAndSettle();
      final guide = tester.widget<WorkspaceGuide>(find.byType(WorkspaceGuide));
      final root = tester.element(find.byType(Scaffold).first);
      showDialog<void>(
        context: root,
        builder: (_) => const AlertDialog(content: Text('Other dialog')),
      );
      await tester.pumpAndSettle();
      guide.onClose();
      await tester.pumpAndSettle();
      expect(find.text('Other dialog'), findsOneWidget);
      expect(find.byKey(const ValueKey('touch-workspace-menu')), findsNothing);
      expect(find.byType(WorkspaceGuide), findsNothing);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'practice Save creates a copy without changing original or undo',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      final files = vm.files as MemoryFiles;
      files.content['/notes/original.md'] = '# Original';
      await vm.openPath('/notes/original.md');
      vm.editor.replaceSelection('User edit');
      final original = vm.editor.text;
      await tester.pumpWidget(VexApp(viewModel: vm));
      vm.startGuide();
      vm.advanceGuide(7);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(vm.strings.saveTooltip));
      await tester.pumpAndSettle();
      expect(files.content['/notes/original.md'], '# Original');
      expect(files.lastSaveName, '${vm.strings.quickStart}.md');
      expect(vm.current.path, '/notes/original.md');
      vm.endGuide();
      await tester.pumpAndSettle();
      expect(vm.editor.text, original);
      expect(vm.editor.session.isDirty, isTrue);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
}
