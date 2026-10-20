import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_outline.dart';
import 'package:vex/ui/workspace/workspace_sidebar.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'desktop sidebars are independent, resize and follow visible views',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.showStructure(true);
      vm.editor.session.replace(
        List.generate(90, (i) => '## 章节 $i\n\n正文 $i\n\n').join(),
      );
      vm.setLayout(WorkspaceLayout.read);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final navigator = find.byType(WorkspaceSidebar);
      final outline = find.byType(WorkspaceOutline);
      final surface = find.byKey(const ValueKey('document-surface'));
      expect(find.byKey(const ValueKey('sidebar-outline')), findsNothing);
      expect(
        tester.getRect(navigator).right,
        lessThan(tester.getRect(surface).left),
      );
      expect(
        tester.getRect(outline).left,
        greaterThan(tester.getRect(surface).right),
      );
      expect(tester.getSize(outline).width, 312);
      final toggle = find.byKey(const ValueKey('document-outline-toggle'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(outline, findsNothing);
      expect(navigator, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final splitter = find.byKey(const ValueKey('structure-splitter'));
      await tester.drag(splitter, const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(tester.getSize(outline).width, greaterThan(275));
      final width = vm.structureWidth;
      Focus.of(tester.element(splitter)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(vm.structureWidth, width + 12);
      expect(
        (vm.settings as MemorySettings).value['structureWidth'],
        vm.structureWidth,
      );
      vm.showFind();
      vm.search('正文 85');
      vm.nextMatch();
      await tester.pumpAndSettle();
      expect(vm.layout, WorkspaceLayout.read);
      expect(find.byType(MarkdownSourceEditor), findsNothing);
      final heading = find.byKey(
        ValueKey('structure-heading-${vm.selectedHeadingId}'),
      );
      expect(heading, findsOneWidget);
      expect(
        tester.getRect(outline).contains(tester.getCenter(heading)),
        isTrue,
      );
      await tester.tap(heading);
      await tester.pumpAndSettle();
      expect(vm.layout, WorkspaceLayout.read);
      expect(find.byType(MarkdownSourceEditor), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'narrow windows overlay structure without squeezing the document',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.showStructure(true);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final outline = find.byType(WorkspaceOutline);
      expect(outline, findsOneWidget);
      tester.view.physicalSize = const Size(900, 700);
      await tester.pumpAndSettle();
      expect(outline, findsOneWidget);
      expect(
        find.byKey(const ValueKey('workspace-structure-overlay')),
        findsOneWidget,
      );
      final surface = tester.getRect(
        find.byKey(const ValueKey('document-surface')),
      );
      expect(surface.right, 900);
      expect(tester.getRect(outline).overlaps(surface), isTrue);
      expect(vm.structure, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(outline, findsNothing);
      await tester.tap(find.byKey(const ValueKey('document-outline-toggle')));
      await tester.pumpAndSettle();
      expect(outline, findsOneWidget);
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('workspace-structure-overlay')),
        findsNothing,
      );
      expect(
        tester.getRect(outline).left,
        greaterThan(
          tester.getRect(find.byKey(const ValueKey('document-surface'))).right,
        ),
      );
      vm.showStructure(false);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(outline, findsNothing);
      expect((vm.settings as MemorySettings).value['structure'], isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
