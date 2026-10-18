import 'package:flutter/material.dart';

enum MindMapStyle { quiet, colorful, outline, capsule, underline, mono }

/// Shared tokens for the canvas, overview and appearance thumbnails.
final class MindMapNodeStyle {
  const MindMapNodeStyle(
    this.fill,
    this.foreground,
    this.border,
    this.radius,
    this.underline,
  );
  final Color fill, foreground, border;
  final double radius;
  final bool underline;

  static MindMapNodeStyle resolve(
    MindMapStyle style,
    ColorScheme colors, {
    required bool root,
    bool selected = false,
    int branch = 0,
  }) {
    const branches = [
      Color(0xff24766b),
      Color(0xff4776a5),
      Color(0xff956bb0),
      Color(0xffad6748),
    ];
    final accent = style == MindMapStyle.mono
        ? colors.onSurface
        : style == MindMapStyle.colorful
        ? branches[branch % branches.length]
        : colors.primary;
    final outline =
        style == MindMapStyle.outline || style == MindMapStyle.underline;
    return MindMapNodeStyle(
      root && !outline
          ? accent
          : selected
          ? accent.withValues(alpha: .16)
          : outline
          ? colors.surface
          : style == MindMapStyle.colorful
          ? accent.withValues(alpha: .09)
          : colors.surfaceContainerLow,
      root && !outline ? colors.surface : colors.onSurface,
      selected || root || outline || style == MindMapStyle.colorful
          ? accent
          : colors.outlineVariant,
      style == MindMapStyle.capsule
          ? 32
          : style == MindMapStyle.mono
          ? 2
          : 7,
      style == MindMapStyle.underline,
    );
  }

  BoxDecoration get decoration => BoxDecoration(
    color: fill,
    borderRadius: underline ? null : BorderRadius.circular(radius),
    border: underline
        ? Border(bottom: BorderSide(color: border, width: 2))
        : Border.all(color: border),
  );
}
