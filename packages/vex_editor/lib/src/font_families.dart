import 'package:flutter/material.dart';

/// Host-selected fonts. The editor package does not ship a font library.
@immutable
class MarkdownFontFamilies extends ThemeExtension<MarkdownFontFamilies> {
  const MarkdownFontFamilies({
    this.serif = 'serif',
    this.serifFallback = const ['sans-serif'],
    this.monospace = 'monospace',
    this.monospaceFallback = const ['sans-serif'],
    this.sansItalic = 'sans-serif',
    this.serifItalic = 'serif',
  });

  final String serif, monospace;
  final String sansItalic, serifItalic;
  final List<String> serifFallback, monospaceFallback;

  static MarkdownFontFamilies of(BuildContext context) =>
      Theme.of(context).extension<MarkdownFontFamilies>() ??
      const MarkdownFontFamilies();

  // CJK UI fonts often produce overlapping synthetic italics. Prefer a real
  // Western italic face and the document's serif CJK fallback for emphasis.
  TextStyle emphasis(TextStyle? body) => TextStyle(
    fontStyle: FontStyle.italic,
    fontFamily: body?.fontFamily == serif ? serifItalic : sansItalic,
    fontFamilyFallback: [serif, ...serifFallback],
  );

  @override
  MarkdownFontFamilies copyWith({
    String? serif,
    List<String>? serifFallback,
    String? monospace,
    List<String>? monospaceFallback,
    String? sansItalic,
    String? serifItalic,
  }) => MarkdownFontFamilies(
    serif: serif ?? this.serif,
    serifFallback: serifFallback ?? this.serifFallback,
    monospace: monospace ?? this.monospace,
    monospaceFallback: monospaceFallback ?? this.monospaceFallback,
    sansItalic: sansItalic ?? this.sansItalic,
    serifItalic: serifItalic ?? this.serifItalic,
  );

  @override
  MarkdownFontFamilies lerp(MarkdownFontFamilies? other, double t) =>
      other == null || t < .5 ? this : other;
}
