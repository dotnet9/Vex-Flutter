import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';

import 'fakes.dart';

Future<void> checkDocumentFrameStability(
  WidgetTester tester, {
  Future<void> Function(String name)? capture,
  GlobalKey? boundary,
}) async {
  final source = List.generate(220, (index) {
    final paragraph =
        'Local text with **formatting**, links and variable length. ' *
        (1 + index % 5);
    return '## Section $index\n\n$paragraph\n\n'
        '${index % 7 == 0 ? '- First item\n- Second item\n\n' : ''}'
        '${index % 11 == 0 ? '```dart\nfinal section = $index;\n```\n\n' : ''}';
  }).join();
  for (final width in [1024.0, 390.0]) {
    await tester.binding.setSurfaceSize(Size(width, 800));
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final layout in [WorkspaceLayout.instant, WorkspaceLayout.read]) {
        final vm = fakeWorkspace();
        (vm.files as MemoryFiles).content['/notes/stability.md'] = source;
        await vm.initialize(watchFiles: false);
        await vm.openPath('/notes/stability.md');
        vm.editor.select(0);
        vm.themeMode = theme;
        vm.setLayout(layout);
        final app = VexApp(viewModel: vm);
        await tester.pumpWidget(
          boundary == null ? app : RepaintBoundary(key: boundary, child: app),
        );
        await tester.pumpAndSettle();
        final list = find.byType(SuperListView);
        expect(list, findsOneWidget);
        expect(
          tester
              .widget<Viewport>(
                find.descendant(of: list, matching: find.byType(Viewport)),
              )
              .scrollCacheExtent,
          ScrollCacheExtent.pixels(tester.getSize(list).height),
        );
        final name = '${width.toInt()}-${theme.name}-${layout.name}';
        for (final index in [180, 5, 160, 165]) {
          final heading = vm.editor.document.headings[index];
          vm.selectHeading(heading);
          await tester.pump();
          await tester.pump();
          final target = find.descendant(
            of: list,
            matching: find.text('Section $index', findRichText: true),
          );
          expect(target, findsOneWidget);
          final first = tester.getRect(target);
          expect(tester.getRect(list).contains(first.center), isTrue);
          expect(
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is RichText &&
                      widget.text.toPlainText().startsWith('Local text'),
                )
                .evaluate(),
            isNotEmpty,
            reason: 'Paragraphs must paint in the arrival frame, not just headings.',
          );
          if (index == 160 || index == 165) {
            await capture?.call('$name-$index-arrived');
          }
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              tester.getRect(target),
              first,
              reason: '$name chapter drift',
            );
          }
          if (index == 160 || index == 165) {
            await capture?.call('$name-$index-settled');
          }
          if (index == 165) {
            expect(find.text('final section = 165;'), findsOneWidget);
          }
        }

        // Wheel/trackpad deltas should render their newly visible text in the
        // same frame, with no late position corrections after input stops.
        for (final delta in [180.0, 480.0, -220.0]) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: tester.getCenter(list),
              scrollDelta: Offset(0, delta),
            ),
          );
          await tester.pump();
          final viewport = tester.getRect(list);
          final visible = <Element, Rect>{};
          for (final element in find.byType(RichText).evaluate()) {
            final box = element.renderObject;
            if (box is! RenderBox || !box.hasSize) continue;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            if (viewport.overlaps(rect) &&
                rect.width > 10 &&
                rect.height > 10) {
              visible[element] = rect;
            }
          }
          expect(visible, isNotEmpty);
          for (var frame = 0; frame < 8; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            for (final entry in visible.entries) {
              expect(entry.key.mounted, isTrue, reason: '$name text replaced');
              final box = entry.key.renderObject! as RenderBox;
              expect(
                box.localToGlobal(Offset.zero) & box.size,
                entry.value,
                reason: '$name scroll drift',
              );
            }
          }
        }
        expect(
          find.byType(MarkdownReader).evaluate().length,
          lessThan(80),
          reason: 'Only the viewport and its bounded cache are built.',
        );
        expect(vm.editor.text, source);
        expect(vm.editor.session.canUndo, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      }
    }
  }
  await tester.binding.setSurfaceSize(null);
}
