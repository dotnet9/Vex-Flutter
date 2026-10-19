import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:vex_markdown_core/vex_markdown_core.dart';

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_view_model.dart';

class WorkspaceSidebar extends StatefulWidget {
  const WorkspaceSidebar({
    super.key,
    required this.vm,
    required this.onOpenPath,
    required this.onAction,
    this.onNavigate,
    this.outlineTabKey,
    this.onOpenInNewWindow,
    this.onRevealInFolder,
  });
  final WorkspaceViewModel vm;
  final ValueChanged<String> onOpenPath;
  final ValueChanged<String> onAction;
  final VoidCallback? onNavigate;
  final Key? outlineTabKey;

  /// 右键菜单：在新窗口打开（document 为当前未保存文档时 path 为 null）。
  final void Function(WorkspaceDocument? document, String? path)?
  onOpenInNewWindow;
  final ValueChanged<String>? onRevealInFolder;

  @override
  State<WorkspaceSidebar> createState() => _WorkspaceSidebarState();
}

class _WorkspaceSidebarState extends State<WorkspaceSidebar> {
  final _collapsed = <String>{};
  late final _search = TextEditingController(text: widget.vm.filter);
  late final _outlineSearch = TextEditingController(
    text: widget.vm.outlineFilter,
  );
  final _searchFocus = FocusNode();
  final _previews = <String, Future<String>>{};
  final _openPreviews = <String, (String, String)>{};
  String? _folderPath;
  int _folderRevision = -1;
  Object? _treeKey;
  List<_SidebarRow> _rows = [];
  int _collapseRevision = 0;
  int _handledSearchFocus = 0;
  WorkspaceViewModel get vm => widget.vm;

  @override
  void dispose() {
    _search.dispose();
    _outlineSearch.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (_folderPath != vm.folder?.path ||
        _folderRevision != vm.folderRevision) {
      if (_folderPath != vm.folder?.path) _collapsed.clear();
      _folderPath = vm.folder?.path;
      _folderRevision = vm.folderRevision;
      _previews.clear();
    }
    if (_handledSearchFocus != vm.sidebarSearchFocus) {
      _handledSearchFocus = vm.sidebarSearchFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !vm.outline) _searchFocus.requestFocus();
      });
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
                    child: KeyedSubtree(
                      key: entry.$1 ? widget.outlineTabKey : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TextButton(
                            key: entry.$1
                                ? const ValueKey('sidebar-outline')
                                : const ValueKey('sidebar-files'),
                            onPressed: () => vm.setOutline(entry.$1),
                            style: TextButton.styleFrom(
                              foregroundColor: vm.outline == entry.$1
                                  ? c.primary
                                  : c.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
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
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SizedBox(
              height: 34,
              child: TextField(
                key: ValueKey(vm.outline ? 'outline-search' : 'sidebar-search'),
                controller: vm.outline ? _outlineSearch : _search,
                focusNode: vm.outline ? null : _searchFocus,
                onChanged: vm.outline ? vm.setOutlineFilter : vm.setFilter,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: vm.outline
                      ? context.l10n.searchOutline
                      : context.l10n.searchDocuments,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(8),
                    child: AppGlyph('search'),
                  ),
                  prefixIconConstraints: const BoxConstraints(maxWidth: 32),
                  suffixIconConstraints: const BoxConstraints(maxWidth: 32),
                  suffixIcon:
                      (vm.outline ? vm.outlineFilter : vm.filter).isEmpty
                      ? null
                      : AppButton(
                          key: const ValueKey('sidebar-clear-search'),
                          icon: 'x',
                          tooltip: context.l10n.clearSearch,
                          height: 30,
                          padding: 4,
                          onPressed: () {
                            (vm.outline ? _outlineSearch : _search).clear();
                            vm.outline
                                ? vm.setOutlineFilter('')
                                : vm.setFilter('');
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
              ),
            ),
          ),
          if (vm.outline)
            Expanded(
              child: Builder(
                builder: (context) {
                  final query = vm.outlineFilter.trim().toLowerCase();
                  final headings = vm.editor.document.headings
                      .where(
                        (heading) =>
                            heading.title.toLowerCase().contains(query),
                      )
                      .toList();
                  return ListView.builder(
                    key: PageStorageKey('outline-${vm.current.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    itemCount: headings.isEmpty ? 1 : headings.length,
                    itemBuilder: (context, index) {
                      if (headings.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            query.isEmpty
                                ? context.l10n.outlineHint
                                : context.l10n.noSearchResults,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }
                      final heading = headings[index];
                      return Padding(
                        key: ValueKey(heading.id),
                        padding: EdgeInsets.only(left: (heading.level - 1) * 9),
                        child: TextButton(
                          onPressed: () {
                            vm.selectHeading(heading);
                            widget.onNavigate?.call();
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
                            textStyle: const TextStyle(fontSize: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: Text(
                            heading.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          else ...[
            Expanded(
              child: vm.fileListMode == FileListMode.list
                  ? _fileList(context)
                  : Builder(
                      builder: (context) {
                        final rows = _files(vm.filter.toLowerCase());
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: rows.length,
                          itemBuilder: (context, index) =>
                              _treeRow(context, rows[index]),
                        );
                      },
                    ),
            ),
            _footer(context),
          ],
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final l = context.l10n, c = Theme.of(context).colorScheme;
    final buttonHeight = vm.viewport == WorkspaceViewport.phone ? 44.0 : 32.0;
    return Container(
      key: const ValueKey('sidebar-footer'),
      height: vm.viewport == WorkspaceViewport.phone ? 52 : 40,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      child: Row(
        children: [
          AppButton(
            height: buttonHeight,
            icon: 'plus',
            tooltip: l.newDocument,
            onPressed: () {
              widget.onAction('new');
              widget.onNavigate?.call();
            },
          ),
          Expanded(
            child: Tooltip(
              message: vm.folder?.path ?? l.openFolder,
              child: TextButton(
                onPressed: () => widget.onAction('folder'),
                child: Text(
                  vm.folder == null
                      ? l.openFolder
                      : p.basename(vm.folder!.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
          MenuAnchor(
            consumeOutsideTap: true,
            alignmentOffset: const Offset(0, -4),
            menuChildren: [
              MenuItemButton(
                leadingIcon: const AppGlyph('plus'),
                onPressed: () => widget.onAction('new'),
                child: Text(l.newDocument),
              ),
              MenuItemButton(
                leadingIcon: const AppGlyph('search'),
                onPressed: _searchFocus.requestFocus,
                child: Text(l.searchDocuments),
              ),
              MenuItemButton(
                leadingIcon: const AppGlyph('folder'),
                onPressed: () => widget.onAction('folder'),
                child: Text(l.openFolder),
              ),
              if (vm.viewport == WorkspaceViewport.desktop)
                MenuItemButton(
                  leadingIcon: const AppGlyph('ext'),
                  onPressed: vm.folder == null
                      ? null
                      : () => widget.onAction('reveal-folder'),
                  child: Text(l.revealFolder),
                ),
              MenuItemButton(
                leadingIcon: const AppGlyph('refresh'),
                onPressed: vm.folder == null
                    ? null
                    : () => widget.onAction('folder-refresh'),
                child: Text(l.refreshFolder),
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: vm.fileSortDescending
                    ? null
                    : const AppGlyph('check'),
                onPressed: () => vm.setFileSortDescending(false),
                child: Text(l.fileSortAscending),
              ),
              MenuItemButton(
                leadingIcon: vm.fileSortDescending
                    ? const AppGlyph('check')
                    : null,
                onPressed: () => vm.setFileSortDescending(true),
                child: Text(l.fileSortDescending),
              ),
            ],
            builder: (context, controller, _) => AppButton(
              height: buttonHeight,
              key: const ValueKey('sidebar-file-actions'),
              icon: 'more',
              tooltip: l.fileActions,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
          AppButton(
            height: buttonHeight,
            key: const ValueKey('sidebar-view-toggle'),
            icon: vm.fileListMode == FileListMode.tree ? 'list' : 'map',
            tooltip: vm.fileListMode == FileListMode.tree
                ? l.fileListView
                : l.fileTreeView,
            onPressed: () => vm.setFileListMode(
              vm.fileListMode == FileListMode.tree
                  ? FileListMode.list
                  : FileListMode.tree,
            ),
          ),
        ],
      ),
    );
  }

  String _excerpt(String source) =>
      markdownSummaryText(source.substring(0, source.length.clamp(0, 8192)))
          .characters
          .take(120)
          .join();

  /// 文件节点右键菜单：在新窗口打开 / 打开文件位置（与桌面原型一致）。
  Future<void> _showFileContextMenu(
    BuildContext context,
    Offset position, {
    required WorkspaceDocument? document,
    required String? path,
  }) async {
    if (vm.viewport == WorkspaceViewport.phone) return;
    final location = document?.path ?? path;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & (overlay?.size ?? Size.zero),
      ),
      items: [
        PopupMenuItem(
          value: 'window',
          enabled: location != null || identical(document, vm.current),
          child: Text(context.l10n.openInNewWindow),
        ),
        PopupMenuItem(
          value: 'reveal',
          enabled: location != null,
          child: Text(context.l10n.openFileLocation),
        ),
      ],
    );
    if (action == null) return;
    if (action == 'window') {
      widget.onOpenInNewWindow?.call(document, location);
    } else if (action == 'reveal' && location != null) {
      widget.onRevealInFolder?.call(location);
    }
  }

  Widget _fileList(BuildContext context) {
    final open = {for (final doc in vm.documents) doc.path ?? doc.id: doc};
    _openPreviews.removeWhere((path, _) => !open.containsKey(path));
    final entries =
        {...?vm.folder?.files, ...open.keys}
            .where(
              (path) => (open[path]?.name ?? p.basename(path))
                  .toLowerCase()
                  .contains(vm.filter.trim().toLowerCase()),
            )
            .toList()
          ..sort(_comparePaths);
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(context.l10n.noSearchResults),
        ),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('sidebar-file-list'),
      itemCount: entries.length,
      itemExtent: 92,
      itemBuilder: (context, index) {
        final path = entries[index], doc = open[path];
        final c = Theme.of(context).colorScheme;
        final selected = identical(doc, vm.current);
        final preview = doc == null
            ? _previews.putIfAbsent(
                path,
                () => vm.files
                    .readPreview(path)
                    .then(_excerpt)
                    .catchError((Object _) => ''),
              )
            : null;
        return Material(
          color: selected ? c.primaryContainer : Colors.transparent,
          child: InkWell(
            key: ValueKey('sidebar-file-$path'),
            onTap: () {
              if (doc != null && doc.path == null) {
                vm.switchDocument(doc);
                widget.onNavigate?.call();
              } else {
                widget.onOpenPath(path);
              }
            },
            onSecondaryTapUp: (event) => _showFileContextMenu(
              context,
              event.globalPosition,
              document: doc,
              path: doc?.path ?? (doc == null ? path : null),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    width: 3,
                    color: selected ? c.primary : Colors.transparent,
                  ),
                  bottom: BorderSide(
                    color: c.outlineVariant.withValues(alpha: .5),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${doc?.name ?? p.basename(path)}${doc?.editor.session.isDirty == true ? ' •' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? c.primary : c.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (doc != null)
                    Text(
                      _openExcerpt(path, doc.editor.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: c.onSurfaceVariant,
                      ),
                    )
                  else
                    FutureBuilder<String>(
                      future: preview,
                      builder: (context, snapshot) => Text(
                        snapshot.data?.isNotEmpty == true
                            ? snapshot.data!
                            : p.relative(path, from: vm.folder?.path),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _comparePaths(String a, String b) {
    final result = p
        .basename(a)
        .toLowerCase()
        .compareTo(p.basename(b).toLowerCase());
    final compared = result == 0 ? a.compareTo(b) : result;
    return vm.fileSortDescending ? -compared : compared;
  }

  String _openExcerpt(String path, String text) {
    final cached = _openPreviews[path];
    if (cached != null && identical(cached.$1, text)) return cached.$2;
    final excerpt = _excerpt(text);
    _openPreviews[path] = (text, excerpt);
    return excerpt;
  }

  List<_SidebarRow> _files(String filter) {
    final folder = vm.folder;
    final key = (
      folder,
      filter,
      vm.documents.map((doc) => '${doc.id}:${doc.path}:${doc.name}').join('|'),
      vm.fileSortDescending,
      _collapseRevision,
    );
    if (_treeKey == key) return _rows;
    _treeKey = key;
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
    return _rows = [
      if (root != null && root.matches(filter))
        ..._directory(root, open, filter, 0),
      for (final doc in vm.documents)
        if ((root == null ||
                doc.path == null ||
                !p.isWithin(root.path, doc.path!)) &&
            doc.name.toLowerCase().contains(filter))
          _SidebarRow(doc.path ?? doc.id, doc.name, document: doc),
    ];
  }

  List<_SidebarRow> _directory(
    _SidebarDirectory node,
    Map<String, WorkspaceDocument> open,
    String filter,
    int depth,
  ) {
    final expanded = filter.isNotEmpty || !_collapsed.contains(node.path);
    final directories = node.directories.values.toList()
      ..sort((a, b) => _comparePaths(a.path, b.path));
    final files = node.files.toList()..sort(_comparePaths);
    return [
      _SidebarRow(
        node.path,
        p.basename(node.path).isEmpty ? node.path : p.basename(node.path),
        depth: depth,
        directory: true,
        expanded: expanded,
      ),
      if (expanded) ...[
        for (final directory in directories)
          if (directory.matches(filter))
            ..._directory(directory, open, filter, depth + 1),
        for (final path in files)
          if (p.basename(path).toLowerCase().contains(filter))
            _SidebarRow(
              path,
              p.basename(path),
              document: open[p.normalize(path)],
              depth: depth + 1,
            ),
      ],
    ];
  }

  Widget _treeRow(BuildContext context, _SidebarRow row) {
    if (!row.directory) {
      return _file(
        context,
        row.path,
        row.name,
        document: row.document,
        depth: row.depth,
      );
    }
    final c = Theme.of(context).colorScheme, depth = row.depth;
    // 文件夹节点与文件节点共用右键菜单：新窗口进入打开文件夹流程、定位目录。
    return GestureDetector(
      onSecondaryTapUp: (event) => _showFileContextMenu(
        context,
        event.globalPosition,
        document: null,
        path: row.path,
      ),
      child: TextButton(
        key: ValueKey('sidebar-directory-${row.path}'),
        onPressed: () => setState(() {
          if (!_collapsed.remove(row.path)) _collapsed.add(row.path);
          _collapseRevision++;
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
              quarterTurns: row.expanded ? 0 : -1,
              child: const AppGlyph('chevron-down', size: 12),
            ),
            const SizedBox(width: 7),
            const AppGlyph('folder', size: 14),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
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
          onSecondaryTapUp: (event) => _showFileContextMenu(
            context,
            event.globalPosition,
            document: document,
            path: document?.path == null
                ? (document == null ? path : null)
                : path,
          ),
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

class _SidebarRow {
  const _SidebarRow(
    this.path,
    this.name, {
    this.document,
    this.depth = 0,
    this.directory = false,
    this.expanded = false,
  });
  final String path, name;
  final WorkspaceDocument? document;
  final int depth;
  final bool directory, expanded;
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
