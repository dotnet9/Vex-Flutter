import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/core/palette_tokens.dart';
import 'package:vex/ui/workspace/workspace_outline.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';
import 'package:vex/ui/workspace/workspace_sidebar.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'palettes, nested menus, article preview and linked panes stay coherent',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const channel = MethodChannel('window_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'isMaximized' ? false : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final output = Platform.environment['VEX_CAPTURE_DIR'];
      final shadows = debugDisableShadows;
      // Optional offline review images use real fonts, with no desktop input.
      if (output != null) {
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = shadows);
        await tester.runAsync(() async {
          for (final (family, path) in [
            ('Roboto', 'C:/Windows/Fonts/msyh.ttc'),
            ('Segoe UI', 'C:/Windows/Fonts/segoeui.ttf'),
            ('Microsoft YaHei UI', 'C:/Windows/Fonts/msyh.ttc'),
            ('SimSun', 'C:/Windows/Fonts/simsun.ttc'),
          ]) {
            if (!File(path).existsSync()) continue;
            final loader = FontLoader(family)
              ..addFont(
                Future.value(
                  ByteData.sublistView(await File(path).readAsBytes()),
                ),
              );
            await loader.load();
          }
          await (FontLoader('CascadiaCode')..addFont(
                rootBundle.load('assets/fonts/CascadiaCode-Regular.ttf'),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          await Directory(output).create(recursive: true);
        });
      }
      final boundary = GlobalKey();
      Future<void> capture(String name) async {
        if (output == null) return;
        List<double>? bounds(Finder finder) {
          if (finder.evaluate().isEmpty) return null;
          final rect = tester.getRect(finder.first);
          return [rect.left, rect.top, rect.width, rect.height];
        }

        final geometry = {
          'size': [1440, 900],
          'scale': 1,
          'language': 'zh',
          'sidebar': bounds(find.byType(WorkspaceSidebar)),
          'outline': bounds(find.byType(WorkspaceOutline)),
          'panes': bounds(find.byType(WorkspacePanes)),
          'document': bounds(find.byKey(const ValueKey('document-surface'))),
          'words': bounds(find.byKey(const ValueKey('document-word-count'))),
        };
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          await File(
            '$output/$name.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(geometry));
          image.dispose();
        });
      }

      void checkMenu() {
        final buttons = find.byWidgetPredicate(
          (widget) => widget is MenuItemButton || widget is SubmenuButton,
        );
        for (final element in buttons.evaluate()) {
          final entry = find.byElementPredicate((e) => e == element);
          final bounds = tester.getRect(entry);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(1440));
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(900));
          for (final state in tester.stateList<ScrollableState>(
            find.ancestor(of: entry, matching: find.byType(Scrollable)),
          )) {
            expect(state.position.maxScrollExtent, 0);
          }
        }
      }

      final vm = fakeWorkspace();
      if (output != null &&
          File('$output/prototype-samples.json').existsSync()) {
        final samples = jsonDecode(
          (await tester.runAsync(
            () => File('$output/prototype-samples.json').readAsString(),
          ))!,
        ) as List;
        final files = vm.files as MemoryFiles;
        for (final sample in samples.cast<Map<String, dynamic>>()) {
          files.content['/演示文档/${sample['name']}'] = sample['text'] as String;
        }
        files.folderPath = '/演示文档';
        await vm.openFolder();
        await vm.openPath(files.content.keys.first);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: VexApp(viewModel: vm, windowIntegration: true),
          ),
        );
        await tester.pumpAndSettle();
        await capture('implementation-desktop');
        for (final layout in [
          WorkspaceLayout.read,
          WorkspaceLayout.map,
          WorkspaceLayout.three,
        ]) {
          vm.setLayout(layout);
          await tester.pumpAndSettle();
          await capture('implementation-${layout.name}');
        }
      }
      vm.editor.session.replace(
        List.generate(
          50,
          (i) =>
              '## 章节 $i · 有序组织思路\n\n'
              '${'协作目标 $i：清晰的层级、连贯的定位，让阅读与编辑保持一致。' * 12}\n\n'
              '> 从当前工作视图出发，保留用户的上下文。\n\n'
              '- 整理内容\n- 交叉检查\n- 记录结论\n\n',
        ).join(),
      );
      vm.editor.session.markSaved();
      vm.setLayout(WorkspaceLayout.read);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: VexApp(viewModel: vm, windowIntegration: true),
        ),
      );
      await tester.pumpAndSettle();
      final document = vm.editor.document;
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final palette in paletteNames.keys) {
          vm.updateAppearance(mode: mode, palette: palette);
          await tester.pumpAndSettle();
          await tester.tap(find.text('视图(V)'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('menu-appearance')));
          await tester.pumpAndSettle();
          checkMenu();
          expect(find.byKey(ValueKey('menu-palette:$palette')), findsOneWidget);
          await capture('$palette-${mode.name}-menus');
          await tester.tap(find.text('视图(V)'));
          await tester.pumpAndSettle();
          expect(identical(vm.editor.document, document), isTrue);
          expect(tester.takeException(), isNull);
        }
      }
      vm.updateAppearance(mode: ThemeMode.light, palette: 'weft');
      await tester.pumpAndSettle();
      await tester.tap(find.text('文件(F)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-export')));
      await tester.pumpAndSettle();
      checkMenu();
      await capture('file-export-menu');
      await tester.tap(find.text('文件(F)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Markdown 排版'));
      await tester.pumpAndSettle();
      for (final type in [
        MarkdownTypography.technical,
        MarkdownTypography.book,
        MarkdownTypography.academic,
      ]) {
        final choice = find.byKey(ValueKey('typography-${type.name}'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        await capture('article-preview-${type.name}');
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      vm.sidebar = false;
      vm.setLayout(WorkspaceLayout.three);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SuperListView).last,
        const Offset(0, -2500),
      );
      await tester.pumpAndSettle();
      expect(vm.editor.viewport.value, isNotNull);
      expect(vm.selectedHeadingId, vm.map.selectedId);
      await capture('three-views-after-scroll');
      vm.setLayout(WorkspaceLayout.read);
      vm.showFind();
      vm.search('协作目标 36');
      vm.nextMatch();
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownSourceEditor), findsNothing);
      expect(vm.selectedHeading?.title, startsWith('章节 36'));
      await capture('read-only-find');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      debugDisableShadows = shadows;
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
