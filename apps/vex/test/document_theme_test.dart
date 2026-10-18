import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/core/app_theme.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('workspace palettes do not change document colors or metrics', (
    tester,
  ) async {
    final styles = <TextStyle>[];
    for (final palette in ['weft', 'graphite', 'sand', 'rose', 'iris']) {
      final shell = appTheme(palette, Brightness.light);
      final document = documentTheme(shell);
      expect(document.colorScheme.surface, Colors.white);
      expect(document.iconTheme.color, document.colorScheme.onSurfaceVariant);
      expect(
        document.inputDecorationTheme.focusedBorder!.borderSide.color,
        document.colorScheme.primary,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: document,
          home: Builder(
            builder: (context) {
              styles.add(const MarkdownReader(data: '').styleSheet(context).p!);
              return const SizedBox();
            },
          ),
        ),
      );
    }
    for (final style in styles) {
      expect(style, styles.first);
    }
    final dark = documentTheme(appTheme('weft', Brightness.dark));
    expect(dark.brightness, Brightness.dark);
    expect(dark.colorScheme.surface, const Color(0xff202124));
  });

  testWidgets(
    'the same document colors apply in writing, reading and presenting',
    (tester) async {
      final vm = fakeWorkspace();
      vm.editor.session.replace('# Title\n\nBody');
      await tester.pumpWidget(VexApp(viewModel: vm));
      for (final palette in ['weft', 'rose']) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          vm.updateAppearance(palette: palette, mode: mode);
          final expected = mode == ThemeMode.light
              ? Colors.white
              : const Color(0xff202124);
          for (final layout in [
            WorkspaceLayout.instant,
            WorkspaceLayout.read,
          ]) {
            vm.setLayout(layout);
            await tester.pumpAndSettle();
            expect(
              Theme.of(tester.element(find.byType(MarkdownReader).first))
                  .colorScheme
                  .surface,
              expected,
            );
          }
          vm.togglePresentation();
          await tester.pumpAndSettle();
          expect(
            Theme.of(tester.element(find.byType(MarkdownReader).first))
                .colorScheme
                .surface,
            expected,
          );
          vm.togglePresentation();
        }
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
