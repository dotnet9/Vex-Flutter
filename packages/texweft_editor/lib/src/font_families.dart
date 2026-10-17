import 'package:flutter/material.dart';

/// Host-selected fonts. The editor package does not ship a font library.
@immutable
class MarkdownFontFamilies extends ThemeExtension<MarkdownFontFamilies> {
  const MarkdownFontFamilies({
    this.serif = 'serif',
    this.serifFallback = const ['sans-serif'],
    this.monospace = 'monospace',
    this.monospaceFallback = const ['sans-serif'],
  });

  final String serif, monospace;
  final List<String> serifFallback, monospaceFallback;

  static MarkdownFontFamilies of(BuildContext context) =>
      Theme.of(context).extension<MarkdownFontFamilies>() ??
      const MarkdownFontFamilies();

  @override
  MarkdownFontFamilies copyWith({
    String? serif,
    List<String>? serifFallback,
    String? monospace,
    List<String>? monospaceFallback,
  }) => MarkdownFontFamilies(
    serif: serif ?? this.serif,
    serifFallback: serifFallback ?? this.serifFallback,
    monospace: monospace ?? this.monospace,
    monospaceFallback: monospaceFallback ?? this.monospaceFallback,
  );

  @override
  MarkdownFontFamilies lerp(MarkdownFontFamilies? other, double t) =>
      other == null || t < .5 ? this : other;
}
