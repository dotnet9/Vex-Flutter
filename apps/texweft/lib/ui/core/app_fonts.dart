import 'package:flutter/foundation.dart';
import 'package:texweft_editor/texweft_editor.dart';

/// Match the prototype's system font strategy without bundling CJK libraries.
abstract final class AppFonts {
  static String get interface => switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'Segoe UI',
    TargetPlatform.iOS || TargetPlatform.macOS => '.SF UI Text',
    TargetPlatform.android => 'Roboto',
    _ => 'sans-serif',
  };

  static const fallback = [
    'Microsoft YaHei UI',
    'PingFang SC',
    'HarmonyOS Sans SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'sans-serif',
  ];

  static MarkdownFontFamilies get markdown => MarkdownFontFamilies(
    serif: switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'SimSun',
      TargetPlatform.iOS || TargetPlatform.macOS => 'Songti SC',
      _ => 'Noto Serif CJK SC',
    },
    serifFallback: const ['Noto Serif SC', 'serif', ...fallback],
    monospace: 'CascadiaCode',
    monospaceFallback: fallback,
  );
}
