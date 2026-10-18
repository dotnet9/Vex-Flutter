import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_menu.dart';

List<WorkspaceMenuEntry> workspaceTouchMenus(List<WorkspaceMenuEntry> menus) {
  final file = menus.firstWhere((item) => item.id == 'file');
  return [
    for (final id in ['new', 'open', 'save', 'export:html'])
      file.children.firstWhere((item) => item.id == id),
    const WorkspaceMenuEntry.separator(),
    ...menus,
  ];
}

Future<String?> showWorkspaceTouchMenu(
  BuildContext context,
  List<WorkspaceMenuEntry> menus, {
  String? title,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  constraints: const BoxConstraints(maxWidth: 520),
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: _TouchMenu(menus: menus, title: title),
    ),
  ),
);

class _TouchMenu extends StatefulWidget {
  const _TouchMenu({required this.menus, this.title});
  final List<WorkspaceMenuEntry> menus;
  final String? title;
  @override
  State<_TouchMenu> createState() => _TouchMenuState();
}

class _TouchMenuState extends State<_TouchMenu> {
  final _path = <WorkspaceMenuEntry>[];
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final items = _path.isEmpty ? widget.menus : _path.last.children;
    return PopScope<String>(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _path.isNotEmpty) setState(() => _path.removeLast());
      },
      child: ConstrainedBox(
        key: const ValueKey('touch-workspace-menu'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                children: [
                  if (_path.isNotEmpty)
                    AppButton(
                      icon: 'arrow-left',
                      height: 44,
                      tooltip: context.l10n.prefBack,
                      onPressed: () => setState(() => _path.removeLast()),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        key: const ValueKey('touch-menu-heading'),
                        _path.isEmpty
                            ? widget.title ?? context.l10n.menuMore
                            : _path.last.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  AppCloseButton(onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Divider(height: 1, color: c.outlineVariant),
            Flexible(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  key: ValueKey(_path.map((item) => item.id).join('/')),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    for (final item in items)
                      if (item.isSeparator)
                        const Divider(height: 13, indent: 20, endIndent: 20)
                      else if (item.toolbar)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              for (final tool in item.children)
                                AppButton(
                                  key: ValueKey('touch-menu-${tool.id}'),
                                  icon: tool.icon,
                                  tooltip: tool.label,
                                  height: 44,
                                  onPressed: tool.enabled
                                      ? () => Navigator.pop(context, tool.id)
                                      : null,
                                ),
                            ],
                          ),
                        )
                      else
                        ListTile(
                          key: ValueKey('touch-menu-${item.id}'),
                          enabled: item.enabled,
                          minTileHeight: 48,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          leading: item.icon != null
                              ? AppGlyph(item.icon!)
                              : item.checked == true
                              ? AppGlyph('check', color: c.primary)
                              : null,
                          title: Text(
                            workspaceMenuLabel(item.label),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15),
                          ),
                          trailing: item.children.isNotEmpty
                              ? const AppGlyph('chevron')
                              : null,
                          onTap: () {
                            if (item.children.isNotEmpty) {
                              setState(() => _path.add(item));
                            } else {
                              Navigator.pop(context, item.id);
                            }
                          },
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
