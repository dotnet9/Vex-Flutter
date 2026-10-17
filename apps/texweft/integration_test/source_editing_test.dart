import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/data/services/desktop_window.dart';
import 'package:texweft/domain/workspace.dart';
import 'package:texweft/ui/workspace/workspace_view_model.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native source clipboard, history, save and close cancellation', (
    tester,
  ) async {
    await initializeDesktopWindow();
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    const path = '/native/source.md';
    const original = '甲🧵\r\n乙\n丙\r丁\r\n';
    const pasted = '替换🧵\r\n第二行';
    const edited = '甲🧵\r\n替换🧵\r\n第二行\n丙\r丁\r\n';
    final files = MemoryFiles()..content[path] = original;
    final recovery = MemoryRecovery();
    final boundary = GlobalKey();
    final vm = WorkspaceViewModel(
      files: files,
      settings: MemorySettings(),
      recovery: recovery,
    );
    await vm.initialize(watchFiles: false);
    await vm.openPath(path);
    vm.setLayout(WorkspaceLayout.source);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TexweftApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();
    final sampleEdits = <Map<String, Object?>>[];

    Future<void> shortcut(LogicalKeyboardKey key) async {
      final physical = switch (key) {
        LogicalKeyboardKey.keyV => PhysicalKeyboardKey.keyV,
        LogicalKeyboardKey.keyZ => PhysicalKeyboardKey.keyZ,
        LogicalKeyboardKey.keyY => PhysicalKeyboardKey.keyY,
        LogicalKeyboardKey.keyS => PhysicalKeyboardKey.keyS,
        _ => throw ArgumentError.value(key),
      };
      vm.editor.sourceFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.controlLeft,
        physicalKey: PhysicalKeyboardKey.controlLeft,
      );
      await tester.sendKeyEvent(key, physicalKey: physical);
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.controlLeft,
        physicalKey: PhysicalKeyboardKey.controlLeft,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
    }

    try {
      expect(find.byType(MarkdownSourceEditor), findsOneWidget);
      vm.editor.select(original.indexOf('乙'), original.indexOf('乙') + 1);
      await Clipboard.setData(const ClipboardData(text: pasted));
      await shortcut(LogicalKeyboardKey.keyV);
      expect(vm.editor.text, edited);
      expect(vm.editor.selection.extentOffset, edited.indexOf('第二行') + 3);
      final captureDir = Platform.environment['TEXWEFT_CAPTURE_DIR'];
      if (captureDir != null) {
        await Directory(captureDir).create(recursive: true);
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$captureDir/source-editor-native.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }
      await shortcut(LogicalKeyboardKey.keyZ);
      expect(vm.editor.text, original);
      expect(vm.editor.session.isDirty, isFalse);
      await shortcut(LogicalKeyboardKey.keyY);
      expect(vm.editor.text, edited);
      await shortcut(LogicalKeyboardKey.keyS);
      expect(files.content[path], edited);
      expect(vm.editor.session.isDirty, isFalse);

      vm.editor.select(0, 1);
      await tester.tap(find.byTooltip('加粗'));
      await tester.pumpAndSettle();
      expect(vm.editor.text, '**甲**${edited.substring(1)}');
      vm.setLayout(WorkspaceLayout.read);
      await tester.pumpAndSettle();
      vm.setLayout(WorkspaceLayout.source);
      await tester.pumpAndSettle();
      await shortcut(LogicalKeyboardKey.keyZ);
      expect(vm.editor.text, edited);
      expect(vm.editor.session.isDirty, isFalse);

      final inputs = Platform.environment['TEXWEFT_STRESS_INPUTS'];
      if (inputs != null) {
        final paths = (jsonDecode(inputs) as List).cast<String>();
        for (final samplePath in paths) {
          final source = await File(samplePath).readAsString();
          files.content[samplePath] = source;
          await vm.openPath(samplePath);
          await tester.pumpAndSettle();
          final offset =
              source.lastIndexOf('\n', (source.length * .85).floor()) + 1;
          const marker = 'Texweft源码验证🧵';
          final updated = source.replaceRange(offset, offset, marker);
          final clock = Stopwatch()..start();
          vm.editor.select(offset);
          await Clipboard.setData(const ClipboardData(text: marker));
          await shortcut(LogicalKeyboardKey.keyV);
          expect(vm.editor.text, updated);
          await shortcut(LogicalKeyboardKey.keyZ);
          expect(vm.editor.text, source);
          expect(vm.editor.session.isDirty, isFalse);
          await shortcut(LogicalKeyboardKey.keyY);
          expect(vm.editor.text, updated);
          await shortcut(LogicalKeyboardKey.keyS);
          expect(files.content[samplePath], updated);
          expect(vm.editor.session.isDirty, isFalse);
          await shortcut(LogicalKeyboardKey.keyZ);
          expect(vm.editor.text, source);
          await shortcut(LogicalKeyboardKey.keyS);
          expect(files.content[samplePath], source);
          expect(vm.editor.session.isDirty, isFalse);
          clock.stop();
          sampleEdits.add({
            'document': 'document-${sampleEdits.length + 1}',
            'utf16Length': source.length,
            'pasteUndoRedoSaveWallMs': clock.elapsedMicroseconds / 1000,
          });
        }
      }
      await vm.openPath(path);
      await tester.pumpAndSettle();

      // Enter runs through the native editor's keyboard actions and formatter.
      vm.editor.session.replace('- [x] 完成');
      vm.editor.select(vm.editor.text.length);
      vm.editor.sourceFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(
        LogicalKeyboardKey.enter,
        physicalKey: PhysicalKeyboardKey.enter,
      );
      await tester.pumpAndSettle();
      expect(vm.editor.text, '- [x] 完成\n- [ ] ');
      await vm.flushRecovery(throwOnError: true);
      expect(recovery.value.single['text'], vm.editor.text);

      // Exercise the real WM_CLOSE interception while keeping the test driver
      // connected; successful native process teardown is checked separately.
      await windowManager.close();
      await tester.pumpAndSettle();
      expect(find.text(vm.strings.keepDraftClose), findsOneWidget);
      await tester.tap(find.text(vm.strings.cancel));
      await tester.pumpAndSettle();
      expect(await windowManager.isVisible(), isTrue);
      expect(vm.editor.text, '- [x] 完成\n- [ ] ');
      expect(tester.takeException(), isNull);
      final output = Platform.environment['TEXWEFT_SOURCE_RESULT'];
      if (output != null) {
        await File(output).writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'completed': true,
            'checks': [
              'native clipboard',
              'UTF-16 selection',
              'mixed line endings',
              'shared undo/redo',
              'save shortcut',
              'toolbar',
              'view switching',
              'Enter continuation',
              'draft recovery',
              'WM_CLOSE cancellation',
            ],
            'sampleEdits': sampleEdits,
          }),
        );
      }
    } finally {
      await Clipboard.setData(clipboard ?? const ClipboardData(text: ''));
      await windowManager.setPreventClose(false);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }
  });
}
