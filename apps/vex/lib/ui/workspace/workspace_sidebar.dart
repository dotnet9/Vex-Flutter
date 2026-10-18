import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_view_model.dart';

class WorkspaceSidebar extends StatefulWidget {
  const WorkspaceSidebar({
    super.key,
    required this.vm,
    required this.onOpenPath,
  });
  final WorkspaceViewModel vm;
  final ValueChanged<String> onOpenPath;

  @override
  State<WorkspaceSidebar> createState() => _WorkspaceSidebarState();
}

class _WorkspaceSidebarState extends State<WorkspaceSidebar> {
  final _collapsed = <String>{};
  late final _search = TextEditingController(text: widget.vm.filter);
  String? _folderPath;
  WorkspaceViewModel get vm => widget.vm;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (_folderPath != vm.folder?.path) {
      _folderPath = vm.folder?.path;
      _collapsed.clear();
    }
    return ColoredBox(
      color: c.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.outlineVariant)),
            ),
            child: Row(
              children: [
                for (final entry in [
                  (false, context.l10n.files),
                  (true, context.l10n.outline),
                ])
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        TextButton(
                          key: ValueKey(
                            entry.$1 ? 'sidebar-outline' : 'sidebar-files',
                          ),
                          onPressed: () => vm.setOutline(entry.$1),
                          style: TextButton.styleFrom(
                            foregroundColor: vm.outline == entry.$1
                                ? c.primary
                                : c.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: const RoundedRectangleBorder(),
                            textStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: vm.outline == entry.$1
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          child: Text(
                            entry.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vm.outline == entry.$1)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 32,
                              height: 2,
                              color: c.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (vm.outline)
            Expanded(
              child: ListView.builder(
                key: PageStorageKey('outline-${vm.current.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                itemCount: vm.editor.document.headings.isEmpty
                    ? 1
                    : vm.editor.document.headings.length,
                itemBuilder: (context, index) {
                  final headings = vm.editor.document.headings;
                  if (headings.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        context.l10n.outlineHint,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }
                  final heading = headings[index];
                  return Padding(
                    key: ValueKey(heading.id),
                    padding: EdgeInsets.only(left: (heading.level - 1) * 9),
                    child: TextButton(
                      onPressed: () => vm.selectHeading(heading),
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
                        textStyle: const TextStyle(fontSize: 14),
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
                  );
                },
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: SizedBox(
                height: 30,
                child: TextField(
                  key: const ValueKey('sidebar-search'),
                  controller: _search,
                  onChanged: vm.setFilter,
                  style: const TextStyle(fontSize: 13),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _files(context, vm.filter.toLowerCase()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _files(BuildContext context, String filter) {
    final folder = vm.folder;
    final open = {
      for (final doc in vm.documents)
        if (doc.path != null) p.normalize(doc.path!): doc,
    };
    final root = folder == null
        ? null
        : _SidebarDirectory(p.normalize(folder.path));
    if (root != null) {
      for (final directory in folder!.directories) {
        root.addDirectory(directory);
      }
      final paths = {
        for (final path in [
          ...folder.files,
          for (final doc in vm.documents)
            if (doc.path != null) doc.path!,
        ])
          p.normalize(path): path,
      };
      for (final path in paths.values) {
        if (p.isWithin(root.path, path)) {
          root.addDirectory(p.dirname(path)).files.add(path);
        }
      }
    }
    return [
      if (root != null && root.matches(filter))
        ..._directory(context, root, open, filter, 0),
      for (final doc in vm.documents)
        if ((root == null ||
                doc.path == null ||
                !p.isWithin(root.path, doc.path!)) &&
            doc.name.toLowerCase().contains(filter))
          _file(context, doc.path ?? doc.id, doc.name, document: doc),
    ];
  }

  List<Widget> _directory(
    BuildContext context,
    _SidebarDirectory node,
    Map<String, WorkspaceDocument> open,
    String filter,
    int depth,
  ) {
    final c = Theme.of(context).colorScheme;
    final expanded = filter.isNotEmpty || !_collapsed.contains(node.path);
    final directories = node.directories.values.toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    final files = node.files.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      TextButton(
        key: ValueKey('sidebar-directory-${node.path}'),
        onPressed: () => setState(() {
          if (!_collapsed.remove(node.path)) _collapsed.add(node.path);
        }),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size(0, 34),
          fixedSize: const Size.fromHeight(34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.only(left: 8 + depth * 14, right: 8),
          foregroundColor: c.onSurface,
          textStyle: const TextStyle(fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Row(
          children: [
            RotatedBox(
              quarterTurns: expanded ? 0 : -1,
              child: const AppGlyph('chevron-down', size: 12),
            ),
            const SizedBox(width: 7),
            const AppGlyph('folder', size: 14),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                p.basename(node.path).isEmpty
                    ? node.path
                    : p.basename(node.path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      if (expanded) ...[
        for (final directory in directories)
          if (directory.matches(filter))
            ..._directory(context, directory, open, filter, depth + 1),
        for (final path in files)
          if (p.basename(path).toLowerCase().contains(filter))
            _file(
              context,
              path,
              p.basename(path),
              document: open[p.normalize(path)],
              depth: depth + 1,
            ),
      ],
    ];
  }

  Widget _file(
    BuildContext context,
    String path,
    String name, {
    WorkspaceDocument? document,
    int depth = 0,
  }) {
    final c = Theme.of(context).colorScheme;
    final selected = identical(document, vm.current);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? c.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: ValueKey('sidebar-file-$path'),
          onTap: () => document != null && document.path == null
              ? vm.switchDocument(document)
              : widget.onOpenPath(path),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 36,
            padding: EdgeInsets.only(left: 8 + depth * 14, right: 9),
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
                if (depth > 0) const SizedBox(width: 19),
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
                      fontSize: 14,
                      color: selected ? c.primary : c.onSurface,
                    ),
                  ),
                ),
                if (document?.editor.session.isDirty ?? false)
                  Text(' •', style: TextStyle(color: c.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarDirectory {
  _SidebarDirectory(this.path);
  final String path;
  final directories = <String, _SidebarDirectory>{};
  final files = <String>{};

  _SidebarDirectory addDirectory(String path) {
    var node = this;
    if (p.equals(this.path, path)) return node;
    if (!p.isWithin(this.path, path)) return node;
    for (final part in p.split(p.relative(path, from: this.path))) {
      final parent = node;
      node = parent.directories.putIfAbsent(
        part,
        () => _SidebarDirectory(p.join(parent.path, part)),
      );
    }
    return node;
  }

  bool matches(String filter) =>
      filter.isEmpty ||
      files.any((path) => p.basename(path).toLowerCase().contains(filter)) ||
      directories.values.any((node) => node.matches(filter));
}
