import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import 'support/fakes.dart';

void main() {
  test(
    'map styles preserve selection, zoom, layout, history and preferences',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      await vm.initialize(watchFiles: false);
      vm.editor.session.replace('# Ideas\n\n## A\n\n### B');
      vm.setLayout(WorkspaceLayout.map);
      vm.map.fit(const Size(900, 600));
      vm.map.zoom(1.3, const Size(900, 600));
      vm.map.select(vm.map.root.children.first.id);
      final transform = vm.map.transformation.value.clone();
      final selected = vm.map.selectedId, revision = vm.editor.session.revision;
      for (final style in MindMapStyle.values) {
        vm.setMapStyle(style);
        expect(vm.map.transformation.value, transform);
        expect(vm.map.selectedId, selected);
        expect(vm.map.fitRequested, isFalse);
        expect(vm.editor.session.revision, revision);
        expect((vm.settings as MemorySettings).value['mapStyle'], style.name);
      }
    },
  );

  testWidgets('nine document choices stay open and map controls are local', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    vm.editor.session.replace(
      '# Title\n\n## Section\n\n### Topic\n\n#### Detail\n\nBody',
    );
    vm.setLayout(WorkspaceLayout.read);
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Markdown 排版'));
    await tester.pumpAndSettle();
    expect(MarkdownTypography.values, hasLength(9));
    final first = tester.getRect(
      find.byKey(const ValueKey('typography-simple')),
    );
    final third = tester.getRect(find.byKey(const ValueKey('typography-book')));
    expect(first.top, third.top);
    expect(first.height, greaterThanOrEqualTo(200));
    for (final type in MarkdownTypography.values) {
      final choice = find.byKey(ValueKey('typography-${type.name}'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(vm.typography, type);
      expect(find.byKey(const ValueKey('typography-picker')), findsOneWidget);
    }
    vm.setLayout(WorkspaceLayout.map);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Markdown 排版'), findsNothing);
    await tester.tap(find.byTooltip('导图样式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('风格'));
    await tester.pumpAndSettle();
    for (final style in MindMapStyle.values) {
      final choice = find.byKey(ValueKey('map-style-${style.name}'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(vm.map.style, style);
      expect(find.byKey(const ValueKey('map-picker')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
