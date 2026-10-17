import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_view_model.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.vm,
    required this.onOpenPath,
    required this.onFolder,
  });
  final WorkspaceViewModel vm;
  final ValueChanged<String> onOpenPath;
  final VoidCallback onFolder;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final filter = vm.filter.toLowerCase();
    return ColoredBox(
      color: c.surfaceContainerLow,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                for (final entry in [
                  (false, context.l10n.files, 'folder'),
                  (true, context.l10n.outline, 'list'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: vm.outline == entry.$1
                              ? Border(
                                  bottom: BorderSide(
                                    color: c.primary,
                                    width: 2,
                                  ),
                                )
                              : null,
                        ),
                        child: AppButton(
                          label: entry.$2,
                          icon: entry.$3,
                          selected: vm.outline == entry.$1,
                          onPressed: () => vm.setOutline(entry.$1),
                          height: 42,
                          padding: 4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (vm.outline) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  Text(
                    context.l10n.documentStructure,
                    style: TextStyle(fontSize: 10, color: c.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    '${vm.editor.document.headings.length}',
                    style: TextStyle(fontSize: 10, color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final heading in vm.editor.document.headings)
                    Padding(
                      padding: EdgeInsets.only(left: (heading.level - 1) * 9),
                      child: TextButton(
                        onPressed: () {
                          vm.selectHeading(heading);
                        },
                        style: TextButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          foregroundColor: vm.selectedHeadingId == heading.id
                              ? c.primary
                              : c.onSurfaceVariant,
                          backgroundColor: vm.selectedHeadingId == heading.id
                              ? c.primaryContainer
                              : null,
                          textStyle: const TextStyle(fontSize: 11.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: Text(
                          'H${heading.level}   ${heading.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (vm.editor.document.headings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        context.l10n.outlineHint,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: SizedBox(
                height: 30,
                child: TextField(
                  onChanged: vm.setFilter,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: context.l10n.searchDocuments,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(8),
                      child: AppGlyph('search', size: 13),
                    ),
                    prefixIconConstraints: const BoxConstraints(maxWidth: 28),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
              child: Row(
                children: [
                  const AppGlyph('folder', size: 14),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      vm.folderName ?? context.l10n.notes,
                      style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppButton(
                    icon: 'folder',
                    tooltip: context.l10n.openMarkdownFolder,
                    onPressed: onFolder,
                    height: 26,
                    padding: 6,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final doc in vm.documents.where(
                    (d) => d.name.toLowerCase().contains(filter),
                  ))
                    _file(
                      context,
                      doc.name,
                      identical(doc, vm.current),
                      () => vm.switchDocument(doc),
                      dirty: doc.editor.session.isDirty,
                    ),
                  for (final path in vm.folderPaths.where(
                    (path) =>
                        p.basename(path).toLowerCase().contains(filter) &&
                        !vm.documents.any((d) => d.path == path),
                  ))
                    _file(
                      context,
                      p.basename(path),
                      false,
                      () => onOpenPath(path),
                    ),
                  if (vm.recent.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 24, 10, 9),
                      child: Text(
                        context.l10n.recentlyOpened,
                        style: TextStyle(
                          fontSize: 10,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final path
                        in vm.recent
                            .where(
                              (v) =>
                                  p.basename(v).toLowerCase().contains(filter),
                            )
                            .take(8))
                      Tooltip(
                        message: path,
                        child: _file(
                          context,
                          p.basename(path),
                          false,
                          () => onOpenPath(path),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _file(
    BuildContext context,
    String name,
    bool selected,
    VoidCallback onTap, {
    bool dirty = false,
  }) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? c.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 30,
            padding: const EdgeInsets.only(left: 8, right: 9),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  width: 3,
                  color: selected ? c.primary : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              children: [
                AppGlyph(
                  'file',
                  size: 14,
                  color: selected ? c.primary : c.onSurfaceVariant,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: selected ? c.primary : c.onSurface,
                    ),
                  ),
                ),
                if (dirty) Text(' •', style: TextStyle(color: c.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
