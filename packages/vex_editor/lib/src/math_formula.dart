import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' as latex;

import 'markdown_preferences.dart';

/// Uses the same native typesetter for preview and offline document exports.
abstract final class MarkdownMathRenderer {
  static latex.ParseOptions options(
    MarkdownPreferences preferences,
    bool display,
  ) => latex.ParseOptions(
    displayMode: display,
    streaming: false,
    trust: false,
    maxExpand: 300,
    maxTokens: 20000,
    maxNodes: 10000,
    maxNesting: 64,
    maxSize: 100,
    timeBudget: const Duration(milliseconds: 200),
    extensions: {
      latex.LatexExtension.siunitx,
      if (preferences.chemistry) latex.LatexExtension.mhchem,
    },
  );

  static latex.MathLayout layout(
    String source, {
    bool display = false,
    MarkdownPreferences preferences = const MarkdownPreferences(),
  }) {
    if (source.length > 8192) throw const FormatException('Formula too long');
    final result = latex.parseLatex(
      source,
      options: options(preferences, display),
    );
    if (result.hasErrors) throw const FormatException('Invalid formula');
    final layout = latex.layoutFormula(
      result,
      options: latex.LayoutOptions(displayMode: display),
      shaper: latex.mathShaperFor(latex.MathTextFonts.latinModern),
    );
    if (!layout.width.isFinite ||
        !layout.height.isFinite ||
        !layout.depth.isFinite ||
        layout.width > 1000 ||
        layout.height + layout.depth > 500) {
      throw const FormatException('Formula exceeds rendering limits');
    }
    return layout;
  }

  static Future<({ui.Size size, Uint8List bytes})> png(
    String source, {
    bool display = false,
    double fontSize = 18,
    Color color = const Color(0xff222222),
    MarkdownPreferences preferences = const MarkdownPreferences(),
  }) async {
    final formula = layout(source, display: display, preferences: preferences);
    final size = ui.Size(
      math.max(1, formula.width * fontSize + 4),
      math.max(1, (formula.height + formula.depth) * fontSize + 4),
    );
    final scale = math.min(
      3.0,
      math.min(
        8192 / math.max(size.width, size.height),
        math.sqrt(16000000 / (size.width * size.height)),
      ),
    );
    await latex.MathPainter.preloadFontsOf(formula.items);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    latex.MathPainter(latex.mathShaperFor(latex.MathTextFonts.latinModern))
        .paint(
          canvas,
          Offset(2, 2 + formula.height * fontSize),
          formula.items,
          fontSize: fontSize,
          color: color,
          devicePixelRatio: scale,
        );
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        (size.width * scale).ceil(),
        (size.height * scale).ceil(),
      );
      try {
        return (
          size: size,
          bytes: (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List(),
        );
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}

class MarkdownMathFormula extends StatelessWidget {
  const MarkdownMathFormula({
    super.key,
    required this.source,
    this.display = false,
    this.fontSize = 16,
    this.preferences = const MarkdownPreferences(),
    this.fallback,
  });
  final String source;
  final bool display;
  final double fontSize;
  final MarkdownPreferences preferences;
  final String? fallback;

  @override
  Widget build(BuildContext context) {
    if (source.length > 8192) return Text(fallback ?? source);
    return latex.Math.tex(
      source,
      displayMode: display,
      wrap: false,
      overflow: display
          ? latex.MathOverflow.scroll
          : latex.MathOverflow.visible,
      textStyle: TextStyle(
        fontSize: fontSize,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      parseOptions: MarkdownMathRenderer.options(preferences, display),
      onError: (_, _) => Text(
        fallback ?? source,
        style: TextStyle(
          fontSize: fontSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
