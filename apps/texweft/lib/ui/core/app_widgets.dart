import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'icon_paths.dart';

class AppGlyph extends StatelessWidget {
  const AppGlyph(this.name, {super.key, this.size = 16, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final value =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final hex = (value.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0');
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#$hex" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${appIconPaths[name] ?? appIconPaths['file']}</svg>',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.tooltip,
    this.selected = false,
    this.bordered = false,
    this.primary = false,
    this.height = 30,
    this.padding = 9,
  });
  final String? label, icon, tooltip;
  final VoidCallback? onPressed;
  final bool selected, bordered, primary;
  final double height, padding;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final foreground = primary
        ? c.onPrimary
        : selected
        ? c.primary
        : c.onSurfaceVariant;
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: primary
            ? c.primary
            : selected
            ? c.primaryContainer
            : null,
        minimumSize: Size(label == null ? height : 0, height),
        padding: EdgeInsets.symmetric(horizontal: padding),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: bordered
              ? BorderSide(color: c.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            AppGlyph(
              icon!,
              color: onPressed == null
                  ? c.onSurface.withValues(alpha: .3)
                  : foreground,
              size: 14,
            ),
          if (icon != null && label != null) const SizedBox(width: 6),
          if (label != null) Text(label!, maxLines: 1),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.height = 32,
  });
  final String title;
  final String? icon;
  final Widget? trailing;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            AppGlyph(icon!, size: 13),
            const SizedBox(width: 7),
          ],
          Text(
            title,
            style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.width = 560,
    this.actions = const [],
  });
  final String title;
  final Widget child;
  final double width;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: MediaQuery.sizeOf(context).height - 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 15, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AppButton(
                  icon: 'x',
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: child,
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ),
        ],
      ),
    ),
  );
}
