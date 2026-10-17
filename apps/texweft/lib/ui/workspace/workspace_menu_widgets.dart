import 'package:flutter/material.dart';

import '../core/app_widgets.dart';
import 'workspace_menu.dart';

List<Widget> workspaceMenuWidgets(
  BuildContext context,
  List<WorkspaceMenuEntry> entries,
  ValueChanged<String> onAction, {
  FocusNode? firstFocusNode,
}) {
  var pendingFocus = firstFocusNode;
  FocusNode? takeFocus(bool enabled) {
    if (!enabled) return null;
    final node = pendingFocus;
    pendingFocus = null;
    return node;
  }

  return [
    for (final item in entries)
      if (item.isSeparator)
        const Divider(height: 13, indent: 8, endIndent: 8)
      else if (item.toolbar)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tool in item.children)
                AppButton(
                  key: ValueKey('menu-${tool.id}'),
                  icon: tool.icon,
                  tooltip: tool.label,
                  onPressed: tool.enabled ? () => onAction(tool.id) : null,
                  focusNode: takeFocus(tool.enabled),
                ),
            ],
          ),
        )
      else if (item.children.isNotEmpty)
        SubmenuButton(
          animated: !MediaQuery.disableAnimationsOf(context),
          key: ValueKey('menu-${item.id}'),
          focusNode: takeFocus(item.enabled),
          leadingIcon: const SizedBox(width: 16),
          menuChildren: workspaceMenuWidgets(context, item.children, onAction),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
      else
        MenuItemButton(
          key: ValueKey('menu-${item.id}'),
          focusNode: takeFocus(item.enabled),
          leadingIcon: SizedBox(
            width: 16,
            child: item.checked == true
                ? const AppGlyph('check')
                : item.icon == null
                ? null
                : AppGlyph(item.icon!),
          ),
          onPressed: item.enabled ? () => onAction(item.id) : null,
          trailingIcon: item.shortcut == null
              ? null
              : Text(
                  workspaceShortcutLabel(item.shortcut),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
  ];
}
