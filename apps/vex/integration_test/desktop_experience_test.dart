import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/preferences_dialog.dart';
import 'package:vex/ui/core/app_widgets.dart';
import 'package:vex/ui/workspace/workspace_dialogs.dart';
import 'package:vex/ui/workspace/workspace_sidebar.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native desktop writing, guide, table and node editing', (
    tester,
  ) async {
    final directory = Platform.environment['VEX_EXPERIENCE_OUTPUT'];
    if (directory == null) {
      fail('Set VEX_EXPERIENCE_OUTPUT to a review directory.');
    }
    await Directory(directory).create(recursive: true);
    final vm = fakeWorkspace();
    await vm.initialize(watchFiles: false);
    await initializeDesktopWindow();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await windowManager.show();
    await windowManager.maximize();
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$directory/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
      expect(tester.takeException(), isNull, reason: name);
    }

    expect(vm.documents, isEmpty);
    final titlebar = find.byKey(const ValueKey('custom-titlebar'));
    final filesTab = find.byKey(const ValueKey('sidebar-files'));
    final outlineTab = find.byKey(const ValueKey('sidebar-outline'));
    void checkChrome({bool dialog = false}) {
      expect(tester.getSize(titlebar).height, 33);
      final header = dialog
          ? find.byKey(const ValueKey('dialog-titlebar')).evaluate().isNotEmpty
                ? find.byKey(const ValueKey('dialog-titlebar'))
                : find.byKey(const ValueKey('preferences-header'))
          : titlebar;
      if (dialog) expect(tester.getSize(header).height, 36);
      final controls = find.descendant(
        of: header,
        matching: find.byType(AppCaptionButton),
      );
      for (final control in controls.evaluate()) {
        expect(
          tester.getSize(find.byElementPredicate((e) => identical(e, control))),
          const Size(46, 32),
        );
      }
      final last = controls.last;
      expect(
        tester.getTopRight(last).dx,
        closeTo(tester.getTopRight(header).dx, 1),
      );
    }

    checkChrome();
    expect(tester.getSize(filesTab).width, tester.getSize(outlineTab).width);
    for (final tab in [filesTab, outlineTab]) {
      expect(
        tester
            .getCenter(find.descendant(of: tab, matching: find.byType(Text)))
            .dx,
        closeTo(tester.getCenter(tab).dx, .1),
      );
      expect(
        find.descendant(of: tab, matching: find.byType(AppGlyph)),
        findsNothing,
      );
    }
    await capture('01-empty');
    await tester.tap(find.text(vm.strings.menuFile));
    await capture('02-file-menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(vm.strings.newDocument), findsNothing);
    final context = tester.element(find.byType(Scaffold).first);
    await tester.tap(find.text(vm.strings.menuHelp));
    await tester.pumpAndSettle();
    await tester.tap(find.text(vm.strings.about));
    await tester.pumpAndSettle();
    checkChrome(dialog: true);
    await capture('03-about');
    await tester.tap(find.byTooltip(vm.strings.close).last);
    await tester.pumpAndSettle();
    checkChrome();
    vm.startGuide();
    for (var step = 0; step < 6; step++) {
      vm.advanceGuide(step);
      await capture('04-guide-${step + 1}');
    }
    vm.endGuide();
    await tester.pumpAndSettle();
    checkChrome();
    expect(vm.documents, isEmpty);
    final files = vm.files as MemoryFiles;
    files.content.addAll({
      '/notes/文章.md': '# 我的文章',
      '/notes/专题/子目录/数学.md': '# 数学方程',
      '/notes/专题/流程.md': '# 流程图',
    });
    files.folderDirectories = ['/notes/专题', '/notes/专题/子目录', '/notes/空目录'];
    await vm.openFolder();
    await tester.pumpAndSettle();
    await capture('04-folder-tree');
    final nested = find.descendant(
      of: find.byType(WorkspaceSidebar),
      matching: find.text('数学.md'),
    );
    expect(nested, findsOneWidget);
    await tester.tap(find.text('专题'));
    await tester.pumpAndSettle();
    expect(nested, findsNothing);
    await tester.enterText(find.byKey(const ValueKey('sidebar-search')), '数学');
    await tester.pumpAndSettle();
    expect(nested, findsOneWidget);
    expect(find.text('流程.md'), findsNothing);
    await capture('04-folder-search');
    await tester.tap(nested);
    await tester.pumpAndSettle();
    expect(vm.current.path, '/notes/专题/子目录/数学.md');
    await tester.tap(find.byKey(const ValueKey('sidebar-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sidebar-search')), '');
    await tester.pumpAndSettle();
    expect(vm.filter, isEmpty);
    expect(nested, findsNothing);
    await tester.tap(find.text('专题'));
    await tester.pumpAndSettle();
    expect(nested, findsOneWidget);
    expect(nested, findsOneWidget);
    const source =
        '# 我的文章\n\n## 章节一\n\n可以直接选择这段文字，并使用上方工具设置格式。\n\n| 输出格式 | 使用场景 |\n| --- | --- |\n| HTML | 网页发布 |\n| PDF | 阅读与分享 |\n\n## 章节二\n\n正文和导图共享同一份内容。';
    vm.editor.session.replace(source);
    await tester.pumpAndSettle();
    await tester.tap(outlineTab);
    await tester.pumpAndSettle();
    expect(find.text(vm.strings.documentStructure), findsNothing);
    await capture('04-outline');
    await tester.tap(filesTab);
    await tester.pumpAndSettle();
    final cell = find.byKey(const ValueKey('table-cell-1-1'));
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.enterText(cell, '直接在单元格编辑');
    await capture('05-table-edit');
    expect(vm.editor.text, contains('| HTML | 直接在单元格编辑 |'));
    vm.setLayout(WorkspaceLayout.map);
    await tester.pumpAndSettle();
    await tester.tap(find.text('章节一'));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(find.text('章节一'));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('mindmap-inline-title'));
    await tester.enterText(title, '原位修改章节标题');
    await capture('06-node-edit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(vm.editor.text, contains('## 原位修改章节标题'));
    final settings = showPreferences(
      context,
      vm,
      category: PreferenceCategory.mcp,
    );
    await tester.pumpAndSettle();
    checkChrome(dialog: true);
    await capture('07-mcp-settings');
    await tester.tap(find.text(vm.strings.done).last);
    await tester.pumpAndSettle();
    await settings;
    await tester.tap(find.byTooltip(vm.strings.close));
    await tester.pumpAndSettle();
    checkChrome(dialog: true);
    await capture('08-unsaved-close');
    await tester.tap(find.text(vm.strings.cancel));
    await tester.pumpAndSettle();
    vm.setLayout(WorkspaceLayout.instant);
    await windowManager.unmaximize();
    for (final width in [900.0, 1024.0, 1440.0]) {
      await windowManager.setSize(Size(width, 850));
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: mode);
        await tester.pumpAndSettle();
        checkChrome();
        await capture('09-${width.toInt()}-${mode.name}');
        final about = showAbout(context);
        await tester.pumpAndSettle();
        checkChrome(dialog: true);
        await capture('10-${width.toInt()}-${mode.name}-about');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await about;
        expect(find.byKey(const ValueKey('dialog-titlebar')), findsNothing);
        checkChrome();
      }
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
