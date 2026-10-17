import 'package:flutter/material.dart';

import 'font_families.dart';
import 'markdown_preferences.dart';
import 'selection_projection.dart';

/// Rich text spans retain every source unit, including zero-width markers, so
/// platform selections, input method composition and undo never need remapping.
class MarkdownInlineEditingController extends TextEditingController {
  MarkdownInlineEditingController({super.text});
  bool presentationEnabled = true;
  bool inlineOnly = false;
  MarkdownPreferences preferences = const MarkdownPreferences();
  String? _parsedText;
  MarkdownPreferences? _parsedPreferences;
  bool? _parsedInlineOnly;
  List<MarkdownInlineToken> _tokens = [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!presentationEnabled || !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    if (_parsedText != text ||
        _parsedPreferences != preferences ||
        _parsedInlineOnly != inlineOnly) {
      _tokens = markdownInlineTokens(text, preferences, inlineOnly: inlineOnly);
      _parsedText = text;
      _parsedPreferences = preferences;
      _parsedInlineOnly = inlineOnly;
    }
    if (_tokens.isEmpty) return TextSpan(text: text, style: style);
    final points = <int>{0, text.length};
    for (final token in _tokens) {
      points.addAll([
        token.range.start,
        token.range.end,
        token.content.start,
        token.content.end,
      ]);
    }
    final boundaries = points.toList()..sort();
    final colors = Theme.of(context).colorScheme;
    final fonts = MarkdownFontFamilies.of(context);
    final children = <TextSpan>[];
    bool revealed(MarkdownInlineToken token) =>
        selection.isValid &&
        [
          selection.baseOffset,
          selection.extentOffset,
        ].any((at) => at >= token.range.start && at <= token.range.end);
    for (var i = 0; i + 1 < boundaries.length; i++) {
      final start = boundaries[i], end = boundaries[i + 1];
      var runStyle = const TextStyle();
      var hidden = false;
      final decorations = <TextDecoration>[];
      for (final token in _tokens) {
        if (start < token.range.start || end > token.range.end) continue;
        final inBody = start >= token.content.start && end <= token.content.end;
        if (!inBody) {
          hidden |= !revealed(token);
          runStyle = runStyle.copyWith(color: colors.onSurfaceVariant);
          continue;
        }
        runStyle = runStyle.merge(switch (token.tag) {
          'strong' => const TextStyle(fontWeight: FontWeight.w700),
          'em' => const TextStyle(fontStyle: FontStyle.italic),
          'code' => TextStyle(
            fontFamily: fonts.monospace,
            fontFamilyFallback: fonts.monospaceFallback,
            fontSize: (style?.fontSize ?? 15) * .87,
            height: 1.8,
            color: colors.primary,
            backgroundColor: colors.surfaceContainerLow,
          ),
          'a' => TextStyle(color: colors.primary),
          'mark' => TextStyle(
            backgroundColor: colors.primary.withValues(alpha: .16),
          ),
          'sub' || 'sup' => TextStyle(fontSize: (style?.fontSize ?? 15) * .85),
          _ => const TextStyle(),
        });
        if (token.tag == 'del') decorations.add(TextDecoration.lineThrough);
        if (token.tag == 'a') decorations.add(TextDecoration.underline);
      }
      if (decorations.isNotEmpty) {
        runStyle = runStyle.copyWith(
          decoration: TextDecoration.combine(decorations),
        );
      }
      if (hidden) {
        runStyle = runStyle.copyWith(
          fontSize: 0,
          height: 0,
          color: Colors.transparent,
          backgroundColor: Colors.transparent,
          decoration: TextDecoration.none,
        );
      }
      children.add(TextSpan(text: text.substring(start, end), style: runStyle));
    }
    return TextSpan(style: style, children: children);
  }
}
