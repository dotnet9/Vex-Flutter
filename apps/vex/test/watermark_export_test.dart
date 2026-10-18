import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/export_service.dart';
import 'package:vex/domain/export_preferences.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/core/palette_tokens.dart';
import 'package:vex/ui/workspace/document_watermark.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';
import 'package:vex/ui/workspace/workspace_dialogs.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  final service = DocumentExportService(),
      colors = paletteSchemes['weft-light']!;
  test(
    'HTML export watermark is independent, escaped and absent by default',
    () async {
      Future<String> html(WatermarkPreferences watermark) => service.html(
        source: '# source',
        title: 'test',
        colors: colors,
        typography: MarkdownTypography.simple,
        watermark: watermark,
      );
      expect(
        await html(const WatermarkPreferences()),
        isNot(contains('<div class="vex-watermark"')),
      );
      expect(
        await html(const WatermarkPreferences(preview: true)),
        isNot(contains('<div class="vex-watermark"')),
      );
      final exported = await html(
        const WatermarkPreferences(export: true, text: '<script>& private'),
      );
      expect(exported, contains('<div class="vex-watermark"'));
      expect(exported, contains('&lt;script&gt;&amp; private'));
      expect(exported, isNot(contains('<script>')));
      expect(exported, contains('fill-opacity="0.12"'));
    },
  );
  testWidgets(
    'preview watermark does not change source, selection or undo history',
    (tester) async {
      final vm = fakeWorkspace();
      vm.editor.session.replace('# source');
      final revision = vm.editor.session.revision;
      final selected = vm.editor.selection;
      await tester.pumpWidget(VexApp(viewModel: vm));
      vm.updateWatermark(preview: true, export: false, text: '机密', opacity: .2);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('document-watermark')), findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('document-watermark')),
                  )
                  .painter!
              as DocumentWatermarkPainter;
      expect(painter.preferences.text, '机密');
      expect(vm.editor.session.revision, revision);
      expect(vm.editor.selection, selected);
      vm.setLayout(WorkspaceLayout.source);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('document-watermark')), findsNothing);
      vm.editor.session.undo();
      expect(vm.editor.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
  test(
    'export and watermark preferences persist with independent switches',
    () async {
      final vm = fakeWorkspace();
      vm.updateWatermark(
        preview: false,
        export: true,
        text: 'a' * 80,
        opacity: .9,
      );
      vm.updateExportPreferences(
        format: 'pdf',
        paper: ExportPaper.letter,
        margin: 25,
        openAfterExport: false,
        folder: '/exports',
        htmlStyle: false,
      );
      final restored = WorkspaceViewModel(
        files: vm.files,
        settings: vm.settings,
        recovery: vm.recovery,
      );
      addTearDown(restored.dispose);
      await restored.initialize(watchFiles: false);
      expect(restored.watermark.preview, isFalse);
      expect(restored.watermark.export, isTrue);
      expect(restored.watermark.text.length, 60);
      expect(restored.watermark.opacity, .5);
      expect(
        restored.exportPreferences.toJson(),
        vm.exportPreferences.toJson(),
      );
      vm.dispose();
    },
  );
  test(
    'PDF watermark spans every page and respects paper format and margins',
    () async {
      final output = Platform.environment['VEX_CAPTURE_DIR'];
      for (final paper in ExportPaper.values) {
        final bytes = await service.pdf(
          source: '# 水印验收\n\n${List.filled(40, '正文不受水印干扰。\n\n').join()}',
          title: '水印验收',
          colors: colors,
          typography: MarkdownTypography.simple,
          preferences: ExportPreferences(paper: paper, margin: 20),
          watermark: const WatermarkPreferences(
            export: true,
            text: '内部审阅',
            opacity: .12,
          ),
        );
        final structure = latin1.decode(bytes);
        expect(structure, contains('/ExtGState'));
        final count = RegExp(r'/Count\s+(\d+)').firstMatch(structure);
        expect(int.parse(count![1]!), greaterThan(1));
        if (output != null) {
          await Directory(output).create(recursive: true);
          await File('$output/watermark-${paper.name}.pdf').writeAsBytes(bytes);
        }
      }
    },
  );
  testWidgets(
    'appearance exposes independent preview and export watermark controls',
    (tester) async {
      final vm = fakeWorkspace();
      await tester.pumpWidget(VexApp(viewModel: vm));
      showAppearance(tester.element(find.byType(Scaffold).first), vm);
      await tester.pumpAndSettle();
      final preview = find.text(vm.strings.watermarkPreview);
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(vm.watermark.preview, isTrue);
      expect(vm.watermark.export, isFalse);
      final text = find.byKey(const ValueKey('watermark-text'));
      await tester.ensureVisible(text);
      await tester.enterText(text, 'Private');
      await tester.pumpAndSettle();
      expect(vm.watermark.text, 'Private');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
  testWidgets(
    'export dialog uses default directory and its independent watermark switch',
    (tester) async {
      final vm = fakeWorkspace();
      vm.editor.session.replace('# Export');
      vm.updateExportPreferences(folder: '/exports', openAfterExport: false);
      await tester.pumpWidget(VexApp(viewModel: vm));
      showExportDialog(tester.element(find.byType(Scaffold).first), vm);
      await tester.pumpAndSettle();
      await tester.tap(find.text(vm.strings.watermarkExport));
      await tester.pumpAndSettle();
      expect(vm.watermark.export, isTrue);
      expect(vm.watermark.preview, isFalse);
      await tester.tap(find.text(vm.strings.htmlPage));
      await tester.pumpAndSettle();
      final files = vm.files as MemoryFiles;
      expect(files.lastInitialDirectory, '/exports');
      expect(files.lastSaveName, endsWith('.html'));
      expect(
        utf8.decode(files.lastSavedBytes!),
        contains('<div class="vex-watermark"'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
