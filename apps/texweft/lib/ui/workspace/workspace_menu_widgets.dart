import 'package:flutter/material.dart';

import '../core/app_widgets.dart';
import 'workspace_menu.dart';

List<Widget> workspaceMenuWidgets(
  BuildContext context,
  List<WorkspaceMenuEntry> entries,
  ValueChanged<String> onAction,
) => [
  for (final item in entries)
    if (item.isSeparator)
      const Divider(height: 13, indent: 8, endIndent: 8)
    else if (item.children.isNotEmpty)
      SubmenuButton(
        key: ValueKey('menu-${item.id}'),
        leadingIcon: const SizedBox(width: 16),
        menuChildren: workspaceMenuWidgets(context, item.children, onAction),
        child: Text(item.label),
      )
    else
      MenuItemButton(
        key: ValueKey('menu-${item.id}'),
        leadingIcon: SizedBox(
          width: 16,
          child: item.checked == true ? const AppGlyph('check') : null,
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
          child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
];
