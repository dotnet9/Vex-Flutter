import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_auxiliary.dart';
import 'package:vex/ui/workspace/workspace_document_info.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';
import 'package:vex/ui/core/app_widgets.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import 'support/fakes.dart';

void main() {
  void window(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'one view menu selects all eight layouts, closes and restores focus',
    (tester) async {
      window(tester, const Size(1440, 900));
      final vm = fakeWorkspace();
      vm.editor.session.replace('# Article\n\n## Chapter\n\nBody');
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final trigger = find.byKey(const ValueKey('workspace-view-selector'));
      expect(tester.getCenter(trigger).dx, closeTo(720, 10));
      expect(
        find.byKey(const ValueKey('document-source-toggle')),
        findsNothing,
      );
      for (final layout in WorkspaceLayout.values) {
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(
          find.byType(MenuItemButton).evaluate().length,
          greaterThanOrEqualTo(8),
        );
        await tester.tap(find.byKey(ValueKey('layout-${layout.name}')));
        await tester.pumpAndSettle();
        expect(vm.layout, layout);
        expect(find.byKey(const ValueKey('layout-read')), findsNothing);
        expect(tester.widget<AppButton>(trigger).focusNode!.hasFocus, isTrue);
        expect(tester.takeException(), isNull, reason: layout.name);
      }
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(vm.layout, WorkspaceLayout.three);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(vm.layout, WorkspaceLayout.source);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'article info stays live; Escape dismisses menus and dialogs before the panel',
    (tester) async {
      window(tester, const Size(1440, 900));
      final vm = fakeWorkspace();
      vm.editor.session.replace('# 文稿\n\nHello 世界');
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final barriers = find.byType(ModalBarrier).evaluate().length;
      await tester.tap(find.byKey(const ValueKey('document-word-count')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceArticleInfo), findsOneWidget);
      expect(find.byType(ModalBarrier).evaluate().length, barriers);
      await tester.tap(find.byKey(const ValueKey('auxiliary-tab-outline')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(vm.auxiliary, WorkspaceAuxiliary.info);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('auxiliary-tab-info')),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      vm.editor.session.replace('# 新文稿\n\nHello world 世界');
      await tester.pumpAndSettle();
      final count = tester.widget<Text>(
        find.byKey(const ValueKey('article-word-count')),
      );
      expect(count.data, vm.strings.wordCount(vm.wordCount));
      await tester.tap(find.byKey(const ValueKey('workspace-view-selector')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(vm.structure, isTrue);
      expect(find.byKey(const ValueKey('layout-read')), findsNothing);
      await tester.tap(find.text(vm.strings.saveDetails).last);
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(vm.structure, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceAuxiliaryPanel), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'map section details edit the right document, keep children and survive undo',
    (tester) async {
      window(tester, const Size(1440, 900));
      final vm = fakeWorkspace();
      const source =
          '# Article\n\n## One\n\nBody\n\n### Child\n\nChild body\n\n## Two\n\nOther';
      vm.editor.session.replace(source);
      vm.setLayout(WorkspaceLayout.map);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final node = vm.map.layout.nodes.values.firstWhere(
        (node) => node.title == 'One',
      );
      tester.widget<MindMapView>(find.byType(MindMapView)).onSelect!(node);
      await tester.pumpAndSettle();
      expect(vm.auxiliary, WorkspaceAuxiliary.chapter);
      expect(find.byType(ChapterInspector), findsOneWidget);
      final title = find.byKey(const ValueKey('chapter-title-input'));
      final body = find.byKey(const ValueKey('chapter-body-input'));
      await tester.enterText(title, 'Renamed');
      await tester.pumpAndSettle();
      expect(vm.editor.text, contains('## Renamed'));
      expect(tester.widget<TextField>(title).controller!.text, 'Renamed');
      await tester.enterText(body, 'Updated **body**');
      await tester.pumpAndSettle();
      expect(vm.editor.text, contains('Updated **body**'));
      expect(vm.editor.text, contains('### Child\n\nChild body'));
      await tester.ensureVisible(find.text(vm.strings.undo).last);
      await tester.tap(find.text(vm.strings.undo).last);
      await tester.pumpAndSettle();
      expect(vm.editor.text, contains('## Renamed\n\nBody'));
      expect(tester.widget<TextField>(body).controller!.text, 'Body');
      await tester.tap(find.text(vm.strings.promote).last);
      await tester.pumpAndSettle();
      expect(vm.selectedHeading!.level, 1);
      expect(vm.selectedHeading!.title, 'Renamed');
      await tester.ensureVisible(find.text(vm.strings.undo).last);
      await tester.tap(find.text(vm.strings.undo).last);
      await tester.pumpAndSettle();
      expect(vm.selectedHeading!.level, 2);
      await tester.tap(find.byKey(const ValueKey('chapter-reveal')));
      await tester.pumpAndSettle();
      expect(vm.layout, WorkspaceLayout.instantMap);
      expect(
        vm.editor.navigation.value!.selection.start,
        vm.selectedHeading!.header.start,
      );
      final selected = vm.selectedHeadingId;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(vm.selectedHeadingId, selected);
      vm.showAuxiliary(WorkspaceAuxiliary.chapter);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(title).controller!.text, 'Renamed');
      final previous = vm.current;
      vm.newDocument();
      await tester.pumpAndSettle();
      expect(find.byType(ChapterInspector), findsNothing);
      expect(find.text(vm.strings.selectChapter), findsOneWidget);
      expect(previous.editor.text, contains('Renamed'));
      expect(vm.editor.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'workspace companions fit light and dark windows without shrinking narrow articles',
    (tester) async {
      window(tester, const Size(1440, 900));
      final vm = fakeWorkspace();
      vm.editor.session.replace(vm.strings.sampleDesign);
      final boundary = GlobalKey();
      final output = Platform.environment['VEX_CHROME_CAPTURE_DIR'];
      final shadows = debugDisableShadows;
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
            final font = File(path);
            if (font.existsSync()) {
              await (FontLoader(family)..addFont(
                    Future.value(
                      ByteData.sublistView(await font.readAsBytes()),
                    ),
                  ))
                  .load();
            }
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
      Future<void> capture(String name) async {
        if (output == null) return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$output/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: VexApp(viewModel: vm),
        ),
      );
      for (final size in [
        const Size(800, 480),
        const Size(1024, 768),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          vm.updateAppearance(mode: mode);
          for (final layout in [
            WorkspaceLayout.instant,
            WorkspaceLayout.read,
            WorkspaceLayout.three,
          ]) {
            vm.setLayout(layout);
            vm.showAuxiliary(WorkspaceAuxiliary.info);
            await tester.pumpAndSettle();
            final panel = tester.getRect(find.byType(WorkspaceAuxiliaryPanel));
            expect(panel.right, size.width);
            expect(panel.top, greaterThan(0));
            expect(panel.bottom, lessThanOrEqualTo(size.height));
            final surface = tester.getRect(
              find.byKey(const ValueKey('document-surface')),
            );
            if (size.width <= 1024 || layout == WorkspaceLayout.three) {
              expect(
                find.byKey(const ValueKey('workspace-structure-overlay')),
                findsOneWidget,
              );
              expect(surface.right, size.width);
            } else {
              expect(surface.width, greaterThanOrEqualTo(640));
            }
            await capture('${layout.name}-${size.width.toInt()}-${mode.name}');
            expect(
              tester.takeException(),
              isNull,
              reason: '$size $mode $layout',
            );
          }
        }
      }
      final surface = tester.getRect(
        find.byKey(const ValueKey('document-surface')),
      );
      await tester.tapAt(Offset(surface.left + 40, surface.top + 100));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceAuxiliaryPanel), findsNothing);
      if (output != null) {
        vm.updateAppearance(mode: ThemeMode.light);
        vm.setLayout(WorkspaceLayout.instant);
        await tester.pumpAndSettle();
        await capture('workspace-default');
        await tester.tap(find.byKey(const ValueKey('titlebar-appearance')));
        await tester.pumpAndSettle();
        await capture('appearance-radios');
        await tester.tap(find.byKey(const ValueKey('appearance-mode-dark')));
        await tester.pumpAndSettle();
        await capture('appearance-radios-dark');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        vm.setLayout(WorkspaceLayout.map);
        vm.selectHeading(vm.editor.document.headings.last);
        vm.showAuxiliary(WorkspaceAuxiliary.chapter);
        await tester.pumpAndSettle();
        vm.map.fit(vm.map.viewportSize!);
        await tester.pumpAndSettle();
        await capture('chapter-details-dark');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      debugDisableShadows = shadows;
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
