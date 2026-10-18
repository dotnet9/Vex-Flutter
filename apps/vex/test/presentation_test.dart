import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/presentation.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_presentation.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'map presentation focuses offscreen chapters and returns to rendered content without editing',
    (tester) async {
      final vm = fakeWorkspace();
      final source =
          '# Deck\n\nIntro\n\n${List.generate(500, (i) => '## Chapter $i\n\nBody $i\n').join('\n')}';
      vm.editor.session.replace(source);
      vm.editor.session.markSaved();
      vm.setLayout(WorkspaceLayout.map);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final beforePresentationTransform = vm.map.transformation.value.clone();
      vm.togglePresentation();
      await tester.pumpAndSettle();
      expect(vm.presenter!.mapMode, isTrue);
      final view = find.byKey(const ValueKey('presentation-map-canvas'));
      expect(tester.widget<MindMapView>(view).onMove, isNull);
      for (final page in [490, 250, 1, 500, 0]) {
        vm.presenter!.goTo(page);
        await tester.pumpAndSettle();
        expect(vm.presenter!.map.selectedId, 'slide-$page');
        final node = find.descendant(
          of: view,
          matching: find.byKey(ValueKey('slide-$page')),
        );
        expect(node, findsOneWidget);
        final rect = tester.getRect(node), canvas = tester.getRect(view);
        expect(rect.center.dx, closeTo(canvas.center.dx, 1));
        expect(rect.center.dy, closeTo(canvas.center.dy, 1));
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const ValueKey('presentation-next')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(vm.presenter!.page, 2);
      await tester.tap(find.byKey(const ValueKey('presentation-markdown')));
      await tester.pumpAndSettle();
      expect(find.text('Body 1').hitTestable(), findsOneWidget);
      vm.togglePresentation();
      await tester.pumpAndSettle();
      expect(vm.layout, WorkspaceLayout.map);
      expect(vm.map.transformation.value, beforePresentationTransform);
      expect(vm.editor.text, source);
      expect(vm.editor.session.isDirty, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
  test('deck preserves every content block once, including fenced headings and rules', () {
    const source =
        '---\r\ntitle: Deck\r\n---\r\n\r\nIntroduction\r\n\r\n'
        '# Title\r\n\r\n## Repeated\r\n\r\n```md\r\n# Code heading\r\n---\r\n```\r\n\r\n'
        '---\r\n\r\n---\r\n\r\nSecond page\r\n\r\n## Repeated\r\n\r\nTail\r\n';
    final document = MarkdownDocument.parse(source);
    final deck = PresentationDeck.fromDocument(document, title: 'Deck.md');
    expect(deck.slides.map((s) => s.title), [
      'Deck.md',
      'Title',
      'Repeated',
      'Repeated',
      'Repeated',
    ]);
    final covered = [
      for (final slide in deck.slides)
        for (var i = slide.firstBlock; i < slide.endBlock; i++) i,
    ];
    expect(covered, [
      for (var i = 0; i < document.blocks.length; i++)
        if (document.blocks[i].kind != MarkdownBlockKind.rule) i,
    ]);
    expect(document.source, source);
    expect(deck.slides[2].headingId, isNot(deck.slides[4].headingId));
    expect(
      document.blocks.where((b) => b.kind == MarkdownBlockKind.code).length,
      1,
    );
  });

  test('empty, headingless and Setext documents have usable decks', () {
    for (final source in [
      '',
      '\n\n',
      '---\n\n---',
      'Text only',
      'Heading\n=======\n\nBody',
    ]) {
      final deck = PresentationDeck.fromDocument(
        MarkdownDocument.parse(source),
        title: 'Notes',
      );
      expect(deck.slides.length, 1);
      expect(
        deck.slides.first.title,
        source.startsWith('Heading') ? 'Heading' : 'Notes',
      );
    }
  });

  test('navigation clamps, outline and zoom remain isolated from workspace settings', () {
    final vm = fakeWorkspace();
    final text = vm.editor.text;
    final layout = vm.layout;
    final savedFontSize = vm.fontSize;
    vm.togglePresentation();
    final controller = vm.presenter!;
    controller.previous();
    expect(controller.page, 0);
    controller.goTo(10000);
    expect(controller.hasNext, isFalse);
    controller.resize(100);
    expect(controller.scale, 2.5);
    controller.resize(-1);
    expect(controller.scale, 1);
    controller.toggleOutline();
    expect(controller.outline, isFalse);
    vm.togglePresentation();
    expect(vm.layout, layout);
    expect(vm.fontSize, savedFontSize);
    expect(vm.editor.text, text);
    expect(vm.editor.session.isDirty, isFalse);
    vm.dispose();
  });

  testWidgets(
    'F5, keyboard and outline navigation preserve source, caret, scroll and layout',
    (tester) async {
      final vm = fakeWorkspace();
      final source =
          '# Cover\n\nIntro\n\n## Details\n\n'
          '${List.generate(100, (i) => 'Paragraph $i\n').join('\n')}\n## Last\n\nThe end.';
      vm.editor.session.replace(source);
      vm.editor.session.markSaved();
      vm.editor.select(10);
      vm.setLayout(WorkspaceLayout.source);
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final sourceScroll = find.descendant(
        of: find.byType(MarkdownSourceEditor),
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(sourceScroll).position.jumpTo(900);
      await tester.pumpAndSettle();
      final selection = vm.editor.selection;
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pumpAndSettle();
      expect(find.byType(WorkspacePresentation), findsOneWidget);
      expect(
        find.byKey(const ValueKey('presentation-progress')),
        findsOneWidget,
      );
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Intro').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.byType(MarkdownReader).evaluate().length, lessThan(35));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(find.text('The end.').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('presentation-page-0')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(WorkspacePresentation), findsNothing);
      expect(vm.layout, WorkspaceLayout.source);
      expect(vm.editor.selection, selection);
      expect(
        tester.state<ScrollableState>(sourceScroll).position.pixels,
        closeTo(900, .1),
      );
      expect(vm.editor.text, source);
      expect(vm.editor.session.isDirty, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );

  testWidgets(
    'all locales fit desktop, tablet and phone at maximum zoom in both themes',
    (tester) async {
      final vm = fakeWorkspace();
      vm.editor.session.replace(
        '# Demo\n\nText with **bold** and `code`.\n\n## More\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n```dart\nprint("Hello");\n```',
      );
      vm.editor.session.markSaved();
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [
        const Size(1440, 900),
        const Size(768, 1024),
        const Size(390, 844),
      ]) {
        await tester.binding.setSurfaceSize(size);
        for (final language in ['zh', 'zh_Hant', 'en', 'ja']) {
          vm.updateAppearance(language: language);
          for (final mode in [ThemeMode.light, ThemeMode.dark]) {
            vm.updateAppearance(mode: mode);
            vm.togglePresentation(outline: size.width >= 700);
            vm.presenter!.resize(2.5);
            await tester.pumpAndSettle();
            final next = find.byKey(const ValueKey('presentation-next'));
            final exit = find.byKey(const ValueKey('presentation-exit'));
            expect(
              tester.getRect(next).overlaps(tester.getRect(exit)),
              isFalse,
            );
            expect(tester.getSize(next).height, greaterThanOrEqualTo(32));
            await tester.tap(next);
            await tester.pumpAndSettle();
            expect(vm.presenter!.page, 1);
            expect(
              find.byType(Table),
              findsOneWidget,
              reason: '$language/$mode/$size',
            );
            await tester.ensureVisible(find.byType(Table));
            await tester.pumpAndSettle();
            expect(
              find.text('A').hitTestable(),
              findsOneWidget,
              reason: '$language/$mode/$size',
            );
            final readers = tester.widgetList<MarkdownReader>(
              find.byType(MarkdownReader),
            );
            expect(
              readers.every((r) => r.fontSize == vm.fontSize * 2.5),
              isTrue,
            );
            await tester.tap(find.byKey(const ValueKey('presentation-map')));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('presentation-map-canvas')),
              findsOneWidget,
            );
            expect(vm.presenter!.map.selectedId, 'slide-1');
            await tester.tap(
              find.byKey(const ValueKey('presentation-map-fit')),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('presentation-markdown')),
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('presentation-outline-toggle')),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$language/$mode/$size',
            );
            await tester.tap(exit);
            await tester.pumpAndSettle();
            expect(vm.presentation, isFalse);
          }
        }
      }
      expect(vm.editor.session.isDirty, isFalse);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
