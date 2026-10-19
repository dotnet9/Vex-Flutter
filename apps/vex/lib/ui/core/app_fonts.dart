import 'package:flutter/foundation.dart';
import 'package:vex_editor/vex_editor.dart';

/// Match the prototype's system font strategy without bundling CJK libraries.
abstract final class AppFonts {
  /// Font-preview builds select the bundled monospace and a window-title
  /// suffix at compile time, e.g.
  /// `--dart-define=VEX_MONO_FONT=MapleMonoCN --dart-define="VEX_MONO_LABEL= - Maple Mono CN"`.
  /// Missing defines fall back to the shipped defaults.
  static const String monospaceFamily = String.fromEnvironment(
    'VEX_MONO_FONT',
    defaultValue: 'CascadiaCode',
  );

  static const String buildLabel = String.fromEnvironment('VEX_MONO_LABEL');

  static String interfaceFor(String language) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (language == 'ja') return 'Yu Gothic UI';
      if (language == 'zh_Hant') return 'Microsoft JhengHei UI';
    }
    return interface;
  }

  static String get interface => switch (defaultTargetPlatform) {
    // Typora-style Windows stack: Segoe UI takes Latin, Microsoft YaHei UI
    // covers CJK via the fallback list — both hinted for small UI sizes.
    TargetPlatform.windows => 'Segoe UI',
    TargetPlatform.iOS || TargetPlatform.macOS => '.SF UI Text',
    TargetPlatform.android => 'Roboto',
    _ => 'sans-serif',
  };

  static const fallback = [
    'Segoe UI',
    'Microsoft YaHei UI',
    'PingFang SC',
    'HarmonyOS Sans SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'sans-serif',
  ];

  static List<String> fallbackFor(String language) => switch (language) {
    'ja' => const [
      'Yu Gothic UI',
      'Yu Gothic',
      'Hiragino Sans',
      'Noto Sans CJK JP',
      'Noto Sans JP',
      'sans-serif',
    ],
    'zh_Hant' => const [
      'Microsoft JhengHei UI',
      'Microsoft JhengHei',
      'PingFang TC',
      'Noto Sans CJK TC',
      'Noto Sans TC',
      'sans-serif',
    ],
    _ => fallback,
  };

  static MarkdownFontFamilies get markdown => MarkdownFontFamilies(
    serif: switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'SimSun',
      TargetPlatform.iOS || TargetPlatform.macOS => 'Songti SC',
      _ => 'Noto Serif CJK SC',
    },
    serifFallback: const ['Noto Serif SC', 'serif', ...fallback],
    monospace: monospaceFamily,
    monospaceFallback: fallback,
    sansItalic: switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'Segoe UI',
      TargetPlatform.iOS || TargetPlatform.macOS => 'Arial',
      _ => 'sans-serif',
    },
    serifItalic: switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => 'Georgia',
      _ => 'serif',
    },
  );

  static MarkdownFontFamilies markdownFor(String language) {
    final serif = switch ((language, defaultTargetPlatform)) {
      ('ja', TargetPlatform.windows) => 'Yu Mincho',
      ('ja', TargetPlatform.iOS || TargetPlatform.macOS) =>
        'Hiragino Mincho ProN',
      ('ja', _) => 'Noto Serif CJK JP',
      ('zh_Hant', TargetPlatform.windows) => 'PMingLiU',
      ('zh_Hant', TargetPlatform.iOS || TargetPlatform.macOS) => 'Songti TC',
      ('zh_Hant', _) => 'Noto Serif CJK TC',
      _ => markdown.serif,
    };
    return markdown.copyWith(
      serif: serif,
      serifFallback: ['serif', ...fallbackFor(language)],
      monospaceFallback: fallbackFor(language),
    );
  }
}
