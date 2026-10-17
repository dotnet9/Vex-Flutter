import 'package:flutter/material.dart';

import 'font_families.dart';

/// Shared, quiet code surface for reading and instant editing.
/// The language editor belongs below this surface, never in its header.
class MarkdownCodeBlock extends StatelessWidget {
  const MarkdownCodeBlock({
    super.key,
    required this.code,
    this.selectable = true,
    this.fontSize = 14,
    this.child,
    this.footer,
    this.wrap = false,
  });

  final String code;
  final bool selectable;
  final bool wrap;
  final double fontSize;
  final Widget? child;
  final Widget? footer;

  static TextStyle textStyle(BuildContext context, double fontSize) {
    final fonts = MarkdownFontFamilies.of(context);
    return TextStyle(
      fontFamily: fonts.monospace,
      fontFamilyFallback: fonts.monospaceFallback,
      fontSize: fontSize,
      height: 22 / 14,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = textStyle(context, fontSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(3),
          ),
          child:
              child ??
              (wrap
                  ? (selectable
                        ? SelectableText(
                            code.isEmpty ? ' ' : code,
                            style: style,
                          )
                        : Text(code.isEmpty ? ' ' : code, style: style))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: selectable
                          ? SelectableText(
                              code.isEmpty ? ' ' : code,
                              style: style,
                            )
                          : Text(code.isEmpty ? ' ' : code, style: style),
                    )),
        ),
        SizedBox(
          height: 32,
          child: Align(alignment: Alignment.centerRight, child: footer),
        ),
      ],
    );
  }
}
