import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/core/app_theme.dart';
import 'package:vex/ui/core/palette_tokens.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'workspace palettes color the document without changing metrics',
    (tester) async {
      final styles = <TextStyle>[];
      for (final brightness in Brightness.values) {
        for (final palette in paletteNames.keys) {
          final shell = appTheme(palette, brightness);
          final document = documentTheme(shell);
          expect(
            document.colorScheme.surface,
            shell.colorScheme.surfaceContainer,
          );
          expect(document.colorScheme.primary, shell.colorScheme.primary);
          expect(document.colorScheme.onSurface, shell.colorScheme.onSurface);
          expect(
            document.iconTheme.color,
            document.colorScheme.onSurfaceVariant,
          );
          expect(
            document.inputDecorationTheme.focusedBorder!.borderSide.color,
            document.colorScheme.primary,
          );
          await tester.pumpWidget(
            MaterialApp(
              themeAnimationDuration: Duration.zero,
              theme: document,
              home: Builder(
                builder: (context) {
                  final style = const MarkdownReader(data: '')
                      .styleSheet(context)
                      .p!;
                  expect(style.color, shell.colorScheme.onSurface);
                  styles.add(style.copyWith(color: Colors.black));
                  return const SizedBox();
                },
              ),
            ),
          );
        }
      }
      for (final style in styles) {
        expect(style, styles.first);
      }
      final dark = documentTheme(appTheme('weft', Brightness.dark));
      expect(dark.brightness, Brightness.dark);
      expect(
        dark.colorScheme.surface,
        appTheme('weft', Brightness.dark).colorScheme.surfaceContainer,
      );
    },
  );

  testWidgets(
    'the same document colors apply in writing, reading and presenting',
    (tester) async {
      final vm = fakeWorkspace();
      vm.editor.session.replace('# Title\n\nBody');
      await tester.pumpWidget(VexApp(viewModel: vm));
      for (final palette in ['weft', 'rose']) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          vm.updateAppearance(palette: palette, mode: mode);
          final expected = appTheme(
            palette,
            mode == ThemeMode.light ? Brightness.light : Brightness.dark,
          ).colorScheme.surfaceContainer;
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
