import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/l10n/l10n.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/core/app_widgets.dart';
import 'package:vex/ui/workspace/workspace_menu.dart';
import 'package:vex/ui/workspace/workspace_touch_menu.dart';

import 'support/fakes.dart';

Iterable<WorkspaceMenuEntry> flatten(List<WorkspaceMenuEntry> entries) sync* {
  for (final entry in entries) {
    yield entry;
    yield* flatten(entry.children);
  }
}

void main() {
  testWidgets('resizing swaps menu anchors without sharing their controllers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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
    final vm = fakeWorkspace()..updateAppearance(language: 'en');
    await tester.pumpWidget(VexApp(viewModel: vm, windowIntegration: true));
    await tester.pumpAndSettle();
    for (final width in [900.0, 700.0, 820.0, 699.0, 390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'resize $width');
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  test(
    'publishing commands are directly available in Tools in reading mode',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.setLayout(WorkspaceLayout.read);
      for (final desktop in [true, false]) {
        final tools = workspaceMenus(
          vm,
          macOS: false,
          desktop: desktop,
          maxPanes: desktop ? 3 : 1,
        ).firstWhere((item) => item.id == 'tools');
        final publishing = tools.children.where(
          (item) => item.id.startsWith('publish:'),
        );
        expect(publishing.map((item) => item.id), [
          'publish:wechat',
          'publish:zhihu',
          'publish:juejin',
        ]);
        expect(
          publishing.every((item) => item.enabled && item.children.isEmpty),
          isTrue,
        );
      }
    },
  );

  test('read-only panes disable all source mutation commands', () {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.editor.replaceSelection('Keep this');
    vm.editor.select(0, 4);
    for (final layout in [
      WorkspaceLayout.read,
      WorkspaceLayout.map,
      WorkspaceLayout.sourceRender,
    ]) {
      vm.setLayout(layout);
      if (layout == WorkspaceLayout.sourceRender) vm.activatePane('read');
      final commands = flatten(
        workspaceMenus(vm, macOS: false, desktop: true, maxPanes: 3),
      );
      expect(
        commands
            .where((item) => workspaceCommandEditsText(item.id))
            .every((item) => !item.enabled),
        isTrue,
      );
      if (layout == WorkspaceLayout.sourceRender) {
        vm.activatePane('source');
        expect(vm.canEditText, isTrue);
      }
    }
  });

  testWidgets(
    'format shortcuts cannot modify a stale selection in reading mode',
    (tester) async {
      final vm = fakeWorkspace();
      vm.editor.session.replace('Keep this');
      vm.editor.select(0, 4);
      vm.setLayout(WorkspaceLayout.read);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(vm.editor.text, 'Keep this');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );

  testWidgets('short touch menus shrink to their content', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showWorkspaceTouchMenu(context, const [
              WorkspaceMenuEntry('copy', 'Copy'),
            ]),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('touch-workspace-menu'))).height,
      lessThan(220),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Alt menu access and delayed paste never modify a switched document',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      vm.editor.session.replace('Original');
      vm.editor.select(0, 8);
      final original = vm.current;
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-paste')), findsOneWidget);
      final pending = Completer<Object?>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return pending.future;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('menu-paste')));
      await tester.pump();
      vm.newDocument();
      pending.complete({'text': 'Delayed paste'});
      await tester.pumpAndSettle();
      expect(original.editor.text, 'Original');
      expect(vm.editor.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  test('seven shared menus contain complete paragraph and format commands', () {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final menus = workspaceMenus(vm, macOS: false, desktop: true, maxPanes: 3);
    expect(menus.map((menu) => menu.id), [
      'file',
      'edit',
      'paragraph',
      'format',
      'view',
      'tools',
      'help',
    ]);
    final commands = flatten(menus).map((entry) => entry.id).toSet();
    expect(
      commands,
      containsAll([
        'format:math',
        'format:footnote',
        'format:highlight',
        'format:superscript',
        'format:subscript',
        'format:clear',
        'watermark',
        'pairs',
        'word-count',
        'motion',
      ]),
    );
    expect(commands.where((id) => id.startsWith('mermaid:')), hasLength(22));
    expect(
      flatten(menus).firstWhere((item) => item.id == 'undo').enabled,
      isFalse,
    );
    vm.editor.replaceSelection('edit');
    expect(
      flatten(workspaceMenus(vm, macOS: false, desktop: true, maxPanes: 3))
          .firstWhere((item) => item.id == 'undo')
          .enabled,
      isTrue,
    );
  });

  test(
    'touch layouts respect pane limits and macOS uses Command conventions',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      for (final limit in [1, 2]) {
        final entries = flatten(
          workspaceMenus(vm, macOS: false, desktop: false, maxPanes: limit),
        );
        final layouts = entries.where((item) => item.id.startsWith('layout:'));
        expect(
          layouts.every(
            (item) =>
                WorkspaceLayout.values
                    .byName(item.id.substring(7))
                    .panes
                    .length <=
                limit,
          ),
          isTrue,
        );
        expect(entries.any((item) => item.id == 'exit'), isFalse);
      }
      final entries = flatten(
        workspaceMenus(vm, macOS: true, desktop: true, maxPanes: 3),
      ).toList();
      final redo = entries.firstWhere((item) => item.id == 'redo').shortcut!;
      expect(redo.meta, isTrue);
      expect(redo.control, isFalse);
      expect(redo.shift, isTrue);
      expect(redo.trigger, LogicalKeyboardKey.keyZ);
      expect(
        entries.any((item) => ['settings', 'about', 'exit'].contains(item.id)),
        isFalse,
      );
    },
  );

  testWidgets('desktop menus have aligned 16px arrows and execute formatting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    vm.editor.session.replace('Text');
    vm.editor.select(0, 4);
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    expect(find.text('Vex'), findsOneWidget);
    await tester.tap(find.text('格式(O)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-format:highlight')));
    await tester.pumpAndSettle();
    expect(vm.editor.text, '==Text==');
    await tester.tap(find.text('视图(V)'));
    await tester.pumpAndSettle();
    final submenuContext = tester.element(
      find.byKey(const ValueKey('menu-appearance')),
    );
    final arrow =
        MenuTheme.of(submenuContext).submenuIcon!.resolve({})! as AppGlyph;
    expect(arrow.size, 16);
    expect(
      tester
          .widget<SubmenuButton>(find.byKey(const ValueKey('menu-appearance')))
          .trailingIcon,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'phone sheet navigates deeply, scrolls only its body and returns an action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace-more-menu')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('touch-workspace-menu'));
      expect(
        find.descendant(of: sheet, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('touch-menu-paragraph')));
      await tester.pumpAndSettle();
      final header = tester.getTopLeft(
        find.byKey(const ValueKey('touch-menu-heading')),
      );
      final mermaid = find.byKey(const ValueKey('touch-menu-mermaid'));
      await tester.scrollUntilVisible(
        mermaid,
        180,
        scrollable: find.descendant(
          of: sheet,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('touch-menu-heading'))),
        header,
      );
      await tester.tap(mermaid);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('touch-menu-mermaid-group-0')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('touch-menu-mermaid:flowchart')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('touch-menu-heading')))
            .data,
        workspaceMenuLabel(vm.strings.menuParagraph),
      );
      await tester.scrollUntilVisible(
        mermaid,
        180,
        scrollable: find.descendant(
          of: sheet,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(mermaid.hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip(vm.strings.close).hitTestable().last);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Android menu clears navigation bar at $size and text scale $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(bottom: 48);
          tester.view.viewPadding = const FakeViewPadding(bottom: 48);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() async {
            tester.view.resetDevicePixelRatio();
            tester.view.resetPadding();
            tester.view.resetViewPadding();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
            await tester.binding.setSurfaceSize(null);
          });
          final vm = fakeWorkspace();
          await tester.pumpWidget(VexApp(viewModel: vm));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('workspace-more-menu')));
          await tester.pumpAndSettle();
          final sheet = find.byKey(const ValueKey('touch-workspace-menu'));
          final help = find.byKey(const ValueKey('touch-menu-help'));
          await tester.scrollUntilVisible(
            help,
            180,
            scrollable: find.descendant(
              of: sheet,
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getBottomRight(sheet).dy,
            lessThanOrEqualTo(size.height - 48),
          );
          expect(
            tester.getBottomRight(help).dy,
            lessThanOrEqualTo(size.height - 48),
          );
          await tester.tap(help);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('touch-menu-heading')))
                .data,
            workspaceMenuLabel(vm.strings.menuHelp),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          vm.dispose();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets('macOS exposes native menus without duplicate custom chrome', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-titlebar')), findsNothing);
    final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
    expect(bar.menus.whereType<PlatformMenu>().map((menu) => menu.label), [
      'Vex',
      '文件',
      '编辑',
      '段落',
      '格式',
      '视图',
      '工具',
      '帮助',
      '窗口',
    ]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
