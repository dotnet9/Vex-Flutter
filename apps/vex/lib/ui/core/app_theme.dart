import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_widgets.dart';
import 'palette_tokens.dart';

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
  );
}
