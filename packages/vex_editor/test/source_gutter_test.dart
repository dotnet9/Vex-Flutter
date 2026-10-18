import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  testWidgets(
    'source restores each document position after switching views or files',
    (tester) async {
      final first = MarkdownEditorController(text: 'line\n' * 300);
      final second = MarkdownEditorController(text: 'other\n' * 200);
      final active = ValueNotifier<MarkdownEditorController?>(first);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: active,
              builder: (context, controller, _) => controller == null
                  ? const SizedBox()
                  : MarkdownSourceEditor(controller: controller),
            ),
          ),
        ),
      );
      ScrollController scroll() =>
          tester.widget<TextField>(find.byType(TextField)).scrollController!;
      scroll().jumpTo(500);
      await tester.pump();
      active.value = second;
      await tester.pumpAndSettle();
      expect(scroll().offset, 0);
      scroll().jumpTo(250);
      await tester.pump();
      active.value = first;
      await tester.pumpAndSettle();
      expect(scroll().offset, 500);
      active.value = null;
      await tester.pump();
      active.value = second;
      await tester.pumpAndSettle();
      expect(scroll().offset, 250);
      await tester.pumpWidget(const SizedBox());
      active.dispose();
      first.dispose();
      second.dispose();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'wrapped source gutter follows actual caret layout at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final editor = MarkdownEditorController(
          text: '${'wrapped ' * 12}\r\nsecond\rthird\n\n',
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: MarkdownSourceEditor(controller: editor, fontSize: 18),
            ),
          ),
        );
        await tester.pumpAndSettle();

        void checkLabels() {
          final gutter = find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter.runtimeType.toString() == '_SourceLineNumbers',
          );
          final box = tester.renderObject<RenderCustomPaint>(gutter);
          final editable = tester
              .state<EditableTextState>(find.byType(EditableText))
              .renderEditable;
          final field = tester.widget<TextField>(find.byType(TextField));
          final starts = [
            0,
            for (final match in RegExp(r'\r\n|\r|\n').allMatches(editor.text))
              match.end,
          ];
          final pattern = paints;
          for (var i = 0; i < starts.length; i++) {
            final caret = editable.getLocalRectForCaret(
              TextPosition(offset: starts[i]),
            );
            final y = box
                .globalToLocal(editable.localToGlobal(caret.center))
                .dy;
            final label = TextPainter(
              text: TextSpan(text: '${i + 1}', style: field.style),
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale),
            )..layout();
            if (y + label.height / 2 < 0 ||
                y - label.height / 2 > box.size.height) {
              label.dispose();
              continue;
            }
            final expected = Offset(
              box.size.width - 12 - label.width,
              y - label.height / 2,
            );
            pattern.paragraph(
              offset: predicate<Offset>(
                (actual) => (actual - expected).distance < .1,
              ),
            );
            label.dispose();
          }
          expect(box, pattern);
        }

        checkLabels();
        editor.source.text = '${'a long line ' * 25}\n${editor.text}';
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        field.scrollController!.jumpTo(
          field.scrollController!.position.maxScrollExtent,
        );
        await tester.pump();
        checkLabels();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        editor.dispose();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }),
    );
  }
}
