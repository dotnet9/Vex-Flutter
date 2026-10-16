import 'package:flutter/material.dart';

/// Shared, quiet code surface for reading and instant editing.
/// The language editor belongs below this surface, never in its header.
class MarkdownCodeBlock extends StatelessWidget {
  const MarkdownCodeBlock({
    super.key,
    required this.code,
    this.selectable = true,
    this.fontSize = 14,
    this.child,
  });

  final String code;
  final bool selectable;
  final double fontSize;
  final Widget? child;

  static TextStyle textStyle(ColorScheme colors, double fontSize) => TextStyle(
    fontFamily: 'Consolas',
    fontFamilyFallback: const ['Cascadia Code', 'Menlo', 'monospace'],
    fontSize: fontSize,
    height: 22 / 14,
    color: colors.onSurface,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = textStyle(colors, fontSize);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(3),
      ),
      child:
          child ??
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: selectable
                ? SelectableText(code.isEmpty ? ' ' : code, style: style)
                : Text(code.isEmpty ? ' ' : code, style: style),
          ),
    );
  }
}
