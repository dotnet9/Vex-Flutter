import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/data/services/update_service.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/builtin_documents.dart';
import 'package:vex/ui/workspace/workspace_dialogs.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native fonts keep source lines, italic runs and active blocks stable',
    (tester) async {
      await initializeDesktopWindow(size: const Size(1280, 900));
      final vm = fakeWorkspace(), boundary = GlobalKey();
      await vm.initialize(watchFiles: false);
      vm.updateAppearance(mode: ThemeMode.light);
      vm.setLayout(WorkspaceLayout.instant);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: VexApp(viewModel: vm),
        ),
      );
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        final directory = Platform.environment['VEX_CAPTURE_DIR'];
        if (directory == null) return;
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        try {
          await Directory(directory).create(recursive: true);
          await File('$directory/$name.png').writeAsBytes(
            (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
                .asUint8List(),
          );
        } finally {
          image.dispose();
        }
      }

      for (final typography in [
        MarkdownTypography.simple,
        MarkdownTypography.book,
      ]) {
        vm.updateAppearance(typography: typography);
        vm.editor.session.replace(
          '# 真实字体检查\n\n磊*33333*尾，中文*斜体*文字。\n\n'
          '普通*italic*123，*333*333，123*333*。',
        );
        await tester.pumpAndSettle();
        await capture('italic-${typography.name}');
      }
      vm.updateAppearance(typography: MarkdownTypography.simple);
      for (final block in [
        '```csharp\nusing System;\nclass Program\n{\n}\n```',
        '- first\n- second\n- third',
        '- [x] first\n- [ ] second',
        '- first\n  - child\n- second',
      ]) {
        vm.editor.session.replace('$block\n\nFollowing paragraph');
        await tester.pumpAndSettle();
        final before = tester.getRect(find.text('Following paragraph'));
        await tester.tap(
          find
              .textContaining(
                block.startsWith('```') ? 'using System;' : 'first',
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Following paragraph')).top,
          closeTo(before.top, .2),
          reason: block,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      vm.editor.session.replace(
        '333\n磊\n\n```csharp\nusing System;\nclass Program {}\n```',
      );
      vm.setLayout(WorkspaceLayout.source);
      await tester.pumpAndSettle();
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      final gutter = tester.widget<DefaultCodeLineNumber>(
        find.byType(DefaultCodeLineNumber),
      );
      expect(gutter.textStyle!.fontSize, editor.style!.fontSize);
      expect(gutter.textStyle!.height, editor.style!.fontHeight);
      await capture('source-line-alignment');
      vm.setLayout(WorkspaceLayout.read);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Markdown 排版'));
      await tester.pumpAndSettle();
      await capture('typography-previews');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('typography-picker')), findsNothing);
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: mode);
        unawaited(
          showAbout(
            tester.element(find.byType(Scaffold).first),
            updates: _UpdatePreview(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('about-check-updates')));
        await tester.pumpAndSettle();
        expect(find.text(vm.strings.updateAvailable('v0.4.0')), findsOneWidget);
        await capture('about-update-${mode.name}');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      vm.updateAppearance(language: 'en', mode: ThemeMode.light);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: VexApp(viewModel: vm, windowIntegration: true),
        ),
      );
      await windowManager.setMinimumSize(const Size(800, 600));
      await windowManager.setSize(const Size(800, 700));
      await tester.pumpAndSettle();
      final header = tester.getRect(
        find.byKey(const ValueKey('custom-titlebar')),
      );
      final close = tester.getRect(find.byTooltip(vm.strings.close));
      expect(close.right, closeTo(header.right, .1));
      await capture('narrow-desktop-menus');
      await windowManager.setMinimumSize(const Size(900, 600));
      await windowManager.setSize(const Size(1000, 780));
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: BuiltinDocumentApp(
              document: BuiltinDocument.changelog,
              source: await BuiltinDocument.changelog.load(),
              brightness: brightness,
              windowIntegration: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final theme = Theme.of(tester.element(find.byType(MarkdownReader)));
        expect(
          theme.colorScheme.surface,
          brightness == Brightness.light
              ? Colors.white
              : const Color(0xff202124),
        );
        await capture('builtin-document-${brightness.name}');
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}

class _UpdatePreview implements UpdateChecker {
  @override
  Future<UpdateCheckResult> check(String? currentVersion) async =>
      const UpdateCheckResult(UpdateStatus.available, tag: 'v0.4.0');
  @override
  void close() {}
}
