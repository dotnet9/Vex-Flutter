import 'package:flutter/material.dart';

import '../core/app_widgets.dart';
import 'workspace_menu.dart';

List<Widget> workspaceMenuWidgets(
  BuildContext context,
  List<WorkspaceMenuEntry> entries,
  ValueChanged<String> onAction, {
  FocusNode? firstFocusNode,
  Size? availableSize,
}) {
  final size = availableSize ?? MediaQuery.sizeOf(context);
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  final rowHeight = (14 * 1.4 * scale + (size.height < 600 ? 8 : 12)).clamp(
    28.0,
    100.0,
  );
  final height = (size.height - 78).clamp(rowHeight, double.infinity);
  final columns = <List<WorkspaceMenuEntry>>[[]];
  var used = 0.0;
  for (final entry in entries) {
    final extent = entry.isSeparator ? 13.0 : rowHeight;
    if (used + extent > height && columns.last.isNotEmpty) {
      while (columns.last.isNotEmpty && columns.last.last.isSeparator) {
        columns.last.removeLast();
      }
      columns.add([]);
      used = 0;
    }
    if (entry.isSeparator && columns.last.isEmpty) continue;
    columns.last.add(entry);
    used += extent;
  }
  final width = ((size.width - 38) / columns.length).clamp(120.0, 350.0);
  final style = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.zero),
    fixedSize: WidgetStatePropertyAll(Size(width, rowHeight)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
  );
  var pendingFocus = firstFocusNode;
  FocusNode? takeFocus(bool enabled) {
    if (!enabled) return null;
    final node = pendingFocus;
    pendingFocus = null;
    return node;
  }

  List<Widget> widgets(List<WorkspaceMenuEntry> column) => [
    for (final item in column)
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
          style: style,
          animated: false,
          key: ValueKey('menu-${item.id}'),
          focusNode: takeFocus(item.enabled),
          leadingIcon: const SizedBox(width: 16),
          menuChildren: workspaceMenuWidgets(
            context,
            item.children,
            onAction,
            availableSize: size,
          ),
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
          style: style,
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
          trailingIcon: item.shortcut == null || (scale > 1.3 && width < 300)
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
  if (columns.length == 1) return widgets(columns.single);
  return [
    IntrinsicHeight(
      child: Row(
        key: const ValueKey('menu-columns'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 9),
            SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widgets(columns[i]),
              ),
            ),
          ],
        ],
      ),
    ),
  ];
}
