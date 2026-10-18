import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
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
      colorFilter: ColorFilter.mode(value, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    this.label,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.tooltip,
    this.selected = false,
    this.bordered = false,
    this.primary = false,
    this.focusNode,
    this.height = 32,
    this.padding = 9,
  });
  final String? label, icon, trailingIcon, tooltip;
  final VoidCallback? onPressed;
  final bool selected, bordered, primary;
  final FocusNode? focusNode;
  final double height, padding;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final foreground = primary
        ? c.onPrimary
        : selected
        ? c.primary
        : c.onSurface;
    final button = TextButton(
      onPressed: onPressed,
      focusNode: focusNode,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: primary
            ? c.primary
            : selected
            ? c.primaryContainer
            : null,
        minimumSize: Size(label == null ? height : 0, height),
        fixedSize: Size.fromHeight(height),
        visualDensity: VisualDensity.standard,
        padding: EdgeInsets.symmetric(horizontal: padding),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
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
              size: 16,
            ),
          if (icon != null && label != null) const SizedBox(width: 6),
          if (label != null)
            Flexible(
              child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 7),
            AppGlyph(trailingIcon!, size: 16, color: foreground),
          ],
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Shared hit area and glyph for dialog, popover and inspector dismissal.
class AppCloseButton extends StatelessWidget {
  const AppCloseButton({super.key, required this.onPressed, this.tooltip});
  final VoidCallback onPressed;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => AppCaptionButton(
    icon: 'x',
    tooltip: tooltip ?? context.l10n.close,
    onPressed: onPressed,
    close: true,
  );
}

/// Native window chrome uses full rectangular targets, matching the prototype.
class AppCaptionButton extends StatelessWidget {
  const AppCaptionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.close = false,
  });
  final String icon, tooltip;
  final VoidCallback onPressed;
  final bool close;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          fixedSize: const WidgetStatePropertyAll(Size(46, 32)),
          minimumSize: const WidgetStatePropertyAll(Size(46, 32)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: c.primary, width: 2)
                : BorderSide.none,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)
                ? close
                      ? const Color(0xffdc2626)
                      : c.surfaceContainerHigh
                : states.contains(WidgetState.focused)
                ? c.primaryContainer
                : Colors.transparent,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) =>
                close &&
                    (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.pressed))
                ? Colors.white
                : states.contains(WidgetState.focused)
                ? c.onPrimaryContainer
                : c.onSurfaceVariant,
          ),
        ),
        child: AppGlyph(icon),
      ),
    );
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
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
            ),
          ),
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
    this.bodyColor,
    this.actions = const [],
    this.canClose = true,
  });
  final String title;
  final Widget child;
  final double width;
  final Color? bodyColor;
  final List<Widget> actions;
  final bool canClose;
  @override
  Widget build(BuildContext context) => Dialog(
    clipBehavior: Clip.antiAlias,
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: MediaQuery.sizeOf(context).height - 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('dialog-titlebar'),
            height: 36,
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IgnorePointer(
                  ignoring: !canClose,
                  child: Opacity(
                    opacity: canClose ? 1 : .4,
                    child: AppCloseButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ColoredBox(
              color: bodyColor ?? Colors.transparent,
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.all(22),
                child: child,
              ),
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
