import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_widgets.dart';
import 'palette_tokens.dart';

/// Document and chrome share semantic colors; typography owns reading metrics.
ThemeData documentTheme(ThemeData shell) {
  final scheme = shell.colorScheme.copyWith(
    surface: shell.colorScheme.surfaceContainer,
  );
  return shell.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 16),
    dividerColor: scheme.outlineVariant,
    dividerTheme: shell.dividerTheme.copyWith(color: scheme.outlineVariant),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: .22),
    ),
    inputDecorationTheme: shell.inputDecorationTheme.copyWith(
      fillColor: scheme.surfaceContainer,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: shell.inputDecorationTheme.border?.copyWith(
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: shell.inputDecorationTheme.enabledBorder?.copyWith(
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: shell.inputDecorationTheme.focusedBorder?.copyWith(
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
    textTheme: shell.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );
}

ThemeData appTheme(
  String palette,
  Brightness brightness, {
  String language = 'zh',
}) {
  final c = paletteSchemes['$palette-${brightness.name}']!;
  return ThemeData(
    useMaterial3: true,
    colorScheme: c,
    scaffoldBackgroundColor: c.surface,
    fontFamily: AppFonts.interfaceFor(language),
    fontFamilyFallback: AppFonts.fallbackFor(language),
    extensions: [AppFonts.markdownFor(language)],
    visualDensity: VisualDensity.standard,
    textTheme: ThemeData(useMaterial3: true).textTheme.apply(
      fontFamily: AppFonts.interfaceFor(language),
      fontFamilyFallback: AppFonts.fallbackFor(language),
      bodyColor: c.onSurface,
      displayColor: c.onSurface,
    ),
    dividerColor: c.outlineVariant,
    dividerTheme: DividerThemeData(
      color: c.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: c.onSurfaceVariant, size: 16),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primary,
      selectionColor: c.primary.withValues(alpha: .22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: c.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      hintStyle: TextStyle(fontSize: 14, color: c.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: c.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: c.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: c.primary),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.outlineVariant),
      ),
    ),
    menuTheme: MenuThemeData(
      submenuIcon: const WidgetStatePropertyAll(AppGlyph('chevron')),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surfaceContainer),
        elevation: const WidgetStatePropertyAll(4),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(5)),
        minimumSize: const WidgetStatePropertyAll(Size(272, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: c.outlineVariant),
          ),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: AppFonts.interfaceFor(language),
            fontFamilyFallback: AppFonts.fallbackFor(language),
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w400,
          ),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? c.onSurface.withValues(alpha: .38)
              : c.onSurface,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? c.primary.withValues(alpha: .14)
              : c.primary.withValues(alpha: .08),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(260, 36)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 550),
    ),
    // Keep the thumb visible whenever a scrollable actually has overflow.
    // Scrollbar itself still suppresses the thumb when there is nothing to scroll.
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => c.onSurfaceVariant.withValues(
          alpha: states.contains(WidgetState.dragged) ? .62 : .32,
        ),
      ),
      trackColor: WidgetStatePropertyAll(c.surfaceContainerLow),
    ),
  );
}
