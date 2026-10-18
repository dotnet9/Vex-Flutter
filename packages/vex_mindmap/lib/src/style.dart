import 'package:flutter/material.dart';

enum MindMapStyle { quiet, colorful, outline, capsule, underline, mono }

Color _accent(MindMapStyle style, ColorScheme colors, int branch) {
  const branches = [
    Color(0xff24766b),
    Color(0xff4776a5),
    Color(0xff956bb0),
    Color(0xffad6748),
  ];
  return switch (style) {
    MindMapStyle.mono => colors.onSurface,
    MindMapStyle.colorful => branches[branch % branches.length],
    _ => colors.primary,
  };
}

final class MindMapEdgeStyle {
  const MindMapEdgeStyle(this.color, this.width);
  final Color color;
  final double width;

  static MindMapEdgeStyle resolve(
    MindMapStyle style,
    ColorScheme colors, {
    int branch = 0,
  }) => MindMapEdgeStyle(
    _accent(style, colors, branch).withValues(
      alpha: style == MindMapStyle.colorful
          ? .85
          : style == MindMapStyle.mono
          ? .55
          : .4,
    ),
    style == MindMapStyle.colorful ? 2 : 1,
  );
}

/// Shared tokens for the canvas, overview and appearance thumbnails.
final class MindMapNodeStyle {
  const MindMapNodeStyle(
    this.fill,
    this.foreground,
    this.border,
    this.radius,
    this.underline, {
    this.strokeWidth = 1,
  });
  final Color fill, foreground, border;
  final double radius, strokeWidth;
  final bool underline;

  static MindMapNodeStyle resolve(
    MindMapStyle style,
    ColorScheme colors, {
    required bool root,
    bool selected = false,
    int branch = 0,
  }) {
    final accent = _accent(style, colors, branch);
    final outline =
        style == MindMapStyle.outline ||
        (style == MindMapStyle.underline && !root);
    return MindMapNodeStyle(
      root && !outline
          ? accent
          : selected
          ? accent.withValues(alpha: .16)
          : outline
          ? colors.surface
          : style == MindMapStyle.mono
          ? colors.surface
          : style == MindMapStyle.colorful
          ? accent.withValues(alpha: .12)
          : style == MindMapStyle.capsule
          ? accent.withValues(alpha: .12)
          : colors.surfaceContainerLow,
      root
          ? outline
                ? accent
                : colors.surface
          : colors.onSurface,
      selected ||
              root ||
              outline ||
              style == MindMapStyle.colorful ||
              style == MindMapStyle.mono
          ? accent
          : style == MindMapStyle.capsule
          ? Colors.transparent
          : colors.outlineVariant,
      style == MindMapStyle.capsule
          ? 32
          : style == MindMapStyle.mono
          ? 2
          : 7,
      style == MindMapStyle.underline && !root,
      strokeWidth:
          selected ||
              (root && style == MindMapStyle.outline) ||
              (style == MindMapStyle.underline && !root)
          ? 2
          : 1,
    );
  }

  BoxDecoration get decoration => BoxDecoration(
    color: fill,
    borderRadius: underline ? null : BorderRadius.circular(radius),
    border: underline
        ? Border(
            bottom: BorderSide(color: border, width: strokeWidth),
          )
        : Border.all(color: border, width: strokeWidth),
  );
}
