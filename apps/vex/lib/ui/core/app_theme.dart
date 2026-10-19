import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_widgets.dart';
import 'palette_tokens.dart';

/// Reading colors are independent of the workspace's accent palette.
ThemeData documentTheme(ThemeData shell) {
  final dark = shell.brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff3975a5),
        brightness: shell.brightness,
      ).copyWith(
        surface: dark ? const Color(0xff202124) : Colors.white,
        onSurface: dark ? const Color(0xffe4e5e7) : const Color(0xff30343b),
        onSurfaceVariant: dark
            ? const Color(0xffafb4bb)
            : const Color(0xff606770),
        surfaceContainerLow: dark
            ? const Color(0xff292b2f)
            : const Color(0xfff6f7f8),
        surfaceContainer: dark
            ? const Color(0xff303238)
            : const Color(0xfff1f3f5),
        outlineVariant: dark
            ? const Color(0xff484c53)
            : const Color(0xffdde1e5),
        primary: dark ? const Color(0xff91bffa) : const Color(0xff3975a5),
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
        backgroundColor: WidgetStatePropertyAll(c.surfaceContainerLow),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(7)),
        minimumSize: const WidgetStatePropertyAll(Size(272, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: c.outlineVariant),
          ),
        ),
      ),
    ),
    menuButtonTheme: const MenuButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14, height: 1.4)),
        minimumSize: WidgetStatePropertyAll(Size(260, 36)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 550),
    ),
    // Keep the thumb visible whenever a scrollable actually has overflow.
    // Scrollbar itself still suppresses the thumb when there is nothing to scroll.
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll(true),
    ),
  );
}
