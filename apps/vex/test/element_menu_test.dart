import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/l10n/l10n.dart';
import 'package:vex/ui/core/app_widgets.dart';
import 'package:vex/ui/workspace/workspace_element_entries.dart';
import 'package:vex/ui/workspace/workspace_element_menu.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'keyboard context menu executes and returns focus to the editor',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final vm = fakeWorkspace();
      vm.editor.session.replace('```dart\nfinal value = 1;\n```\n');
      vm.setLayout(WorkspaceLayout.source);
      await tester.pumpWidget(VexApp(viewModel: vm));
      vm.editor.select(vm.editor.text.indexOf('value'));
      vm.editor.sourceFocus.requestFocus();
      await tester.pumpAndSettle();
      Future<void> open() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.f10);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
      }

      await open();
      expect(
        find.byKey(const ValueKey('menu-element:copy-source')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, 'final value = 1;');
      expect(vm.editor.sourceFocus.hasFocus, isTrue);
      await open();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('menu-element:copy-source')),
        findsNothing,
      );
      expect(vm.editor.sourceFocus.hasFocus, isTrue);

      vm.editor.session.replace('text idea\n');
      vm.setLayout(WorkspaceLayout.instant);
      await tester.pumpAndSettle();
      await tester.tap(find.text('text idea'));
      await tester.pumpAndSettle();
      final input = tester
          .widget<TextField>(find.byKey(const ValueKey('instant-active-input')))
          .controller!;
      input.selection = const TextSelection(baseOffset: 9, extentOffset: 5);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      final cut = tester.widget<AppButton>(
        find.byKey(const ValueKey('menu-element:cut')),
      );
      expect(cut.onPressed, isNotNull);
      expect(cut.focusNode?.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(copied, 'idea');
      expect(vm.editor.text, 'text \n');
      vm.editor.session.undo();
      await tester.pumpAndSettle();
      expect(vm.editor.text, 'text idea\n');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  test('all element menus respect readonly and text/block boundaries', () {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    for (final source in [
      'text\n',
      '- [ ] task\n',
      '```dart\ncode\n```\n',
      r'$$x$$',
      '[link](https://example.com)',
      '![alt](image.png)',
    ]) {
      vm.editor.session.replace(source);
      final target = vm.editor.elementTarget(
        offset: source.contains(']') ? 1 : 0,
      );
      final entries = workspaceElementEntries(vm, target, readOnly: true);
      final ids = [
        for (final entry in entries) entry.id,
        for (final group in entries)
          ...group.children
              .where((item) => item.enabled)
              .map((item) => item.id),
      ];
      expect(ids, isNot(contains('element:delete-block')));
      expect(ids, isNot(contains('element:edit-block')));
      expect(ids, isNot(contains('element:edit-media')));
      expect(ids, isNot(contains('element:paste')));
      expect(ids, isNot(contains('element:cut')));
      if (!target.textBlock) expect(ids, isNot(contains('element-paragraph')));
    }
  });

  testWidgets(
    'desktop link editing preserves source and rejects stale dialogs',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      const source = 'Before [**link**](https://example.com) after\n';
      vm.editor.session.replace(source);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      Future<void> open() async {
        await tester.tap(
          find.byKey(const ValueKey('element-block-0')),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('menu-element:edit-media')));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.enterText(
        find.byKey(const ValueKey('element-edit-url')),
        'https://vex.example/a_(b)',
      );
      await tester.enterText(
        find.byKey(const ValueKey('element-edit-description')),
        'Vex',
      );
      await tester.tap(find.byKey(const ValueKey('element-edit-apply')));
      await tester.pumpAndSettle();
      expect(
        vm.editor.text,
        'Before [Vex](<https://vex.example/a_(b)>) after\n',
      );
      vm.editor.session.undo();
      await tester.pumpAndSettle();
      expect(vm.editor.text, source);
      await open();
      vm.editor.session.replace('new content');
      await tester.tap(find.byKey(const ValueKey('element-edit-apply')));
      await tester.pumpAndSettle();
      expect(vm.editor.text, 'new content');
      expect(find.textContaining(vm.strings.documentChanged), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('code, formula and diagram context edits share atomic undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = fakeWorkspace();
    await tester.pumpWidget(VexApp(viewModel: vm));
    for (final source in [
      '```dart\nold\n```\n',
      r'$$x$$',
      '```mermaid\nflowchart LR\nA --> B\n```\n',
    ]) {
      vm.editor.session.replace(source);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('element-block-0')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-element:edit-block')));
      await tester.pumpAndSettle();
      final next = source.startsWith(r'$$')
          ? r'y^2'
          : source.contains('mermaid')
          ? 'flowchart TB\nB --> C'
          : 'new';
      await tester.enterText(
        find.byKey(const ValueKey('element-edit-source')),
        next,
      );
      await tester.tap(find.byKey(const ValueKey('element-edit-apply')));
      await tester.pumpAndSettle();
      expect(vm.editor.text, contains(next));
      vm.editor.session.undo();
      await tester.pumpAndSettle();
      expect(vm.editor.text, source);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('reading context exposes copying but no document mutations', (
    tester,
  ) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = fakeWorkspace();
    vm.editor.session.replace('Read **only**\n');
    vm.setLayout(WorkspaceLayout.read);
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('read-element-0')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('menu-element:delete-block')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('menu-element-copy-as')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-element:copy-markdown')));
    await tester.pumpAndSettle();
    expect(copied, 'Read **only**\n');
    expect(vm.editor.text, 'Read **only**\n');
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('phone long press keeps a touch sheet and fits link editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = fakeWorkspace();
    vm.editor.session.replace('[Link](https://example.com)\n');
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('element-block-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('touch-workspace-menu')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('touch-menu-element:edit-media')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('element-edit-url')), findsOneWidget);
    expect(tester.getRect(find.byType(Dialog)).right, lessThanOrEqualTo(390));
    await tester.tap(find.text(vm.strings.cancel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('async paste cannot apply after switching documents', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = fakeWorkspace(), pending = Completer<Object?>();
    vm.editor.session.replace('first');
    final first = vm.current;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? pending.future : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    ValueChanged<MarkdownContextRequest>? open;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WorkspaceElementMenu(
            vm: vm,
            onAction: (_) {},
            onError: (_) {},
            builder: (callback) {
              open = callback;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    open!(const MarkdownContextRequest(offset: 0, position: Offset(100, 100)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-element:paste')));
    await tester.pumpAndSettle();
    vm.newDocument();
    pending.complete({'text': 'wrong document'});
    await tester.pumpAndSettle();
    expect(first.editor.text, 'first');
    expect(vm.editor.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'right clicking the second repeated link edits only that occurrence',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.editor.session.replace(
        '[First](https://example.com) and [Second](https://example.com)\n',
      );
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final second = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'First and Second',
      );
      final paragraph = tester.renderObject<RenderParagraph>(second);
      final box = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 10, extentOffset: 11),
          )
          .single;
      await tester.tapAt(
        paragraph.localToGlobal(box.toRect().center),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-element:edit-media')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('element-edit-description')),
        'Changed',
      );
      await tester.tap(find.byKey(const ValueKey('element-edit-apply')));
      await tester.pumpAndSettle();
      expect(
        vm.editor.text,
        '[First](https://example.com) and [Changed](<https://example.com>)\n',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'inserted paragraph accepts typing at its actual source location',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      vm.editor.session.replace('First\n\nSecond\n');
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('element-block-0')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-element-insert')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-element:insert-below')));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('instant-active-input'));
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      await tester.enterText(input, 'Middle');
      await tester.pumpAndSettle();
      expect(vm.editor.text, contains('First\n\nMiddle\n\nSecond'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('tablet element menu remains a touch sheet', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = fakeWorkspace();
    vm.editor.session.replace('- [ ] Task\n');
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('element-block-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('touch-workspace-menu')), findsOneWidget);
    final task = find.byKey(const ValueKey('touch-menu-element:toggle-task'));
    await tester.scrollUntilVisible(
      task,
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('touch-workspace-menu')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(task);
    await tester.pumpAndSettle();
    expect(vm.editor.text, '- [x] Task\n');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
