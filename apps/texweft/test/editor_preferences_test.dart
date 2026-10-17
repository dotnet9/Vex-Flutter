import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/ui/workspace/workspace_view_model.dart';
import 'package:texweft_editor/texweft_editor.dart';

import 'support/fakes.dart';

void main() {
  test(
    'editing and appearance preferences persist without changing source',
    () async {
      final vm = fakeWorkspace();
      vm.editor.session.replace('# unchanged');
      vm.updateEditorPreferences(
        font: MarkdownBodyFont.serif,
        codeSize: 19,
        indent: 8,
        autoPair: false,
        codeWrap: true,
      );
      vm.updateAppearance(
        contentZoom: 1.25,
        fontSize: 24,
        motion: false,
        statusbar: false,
      );
      final restored = WorkspaceViewModel(
        files: vm.files,
        settings: vm.settings,
        recovery: vm.recovery,
      );
      addTearDown(restored.dispose);
      await restored.initialize(watchFiles: false);
      expect(
        restored.editingPreferences.toJson(),
        vm.editingPreferences.toJson(),
      );
      expect(restored.contentZoom, 1.25);
      expect(restored.motion, isFalse);
      expect(restored.statusbar, isFalse);
      expect(restored.fontSize, 24);
      expect(vm.editor.text, '# unchanged');
      vm.dispose();
    },
  );
  testWidgets('pane receives real settings, zoom and reduced motion', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    vm.updateAppearance(contentZoom: 1.25, motion: false);
    vm.updateEditorPreferences(codeSize: 17, indent: 4);
    await tester.pumpWidget(TexweftApp(viewModel: vm));
    final editor = tester.widget<MarkdownInstantEditor>(
      find.byType(MarkdownInstantEditor),
    );
    expect(editor.editingPreferences?.codeSize, 17);
    expect(editor.editingPreferences?.indent, 4);
    final context = tester.element(find.byType(MarkdownInstantEditor));
    expect(MediaQuery.disableAnimationsOf(context), isTrue);
    expect(MediaQuery.textScalerOf(context).scale(16), 20);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
