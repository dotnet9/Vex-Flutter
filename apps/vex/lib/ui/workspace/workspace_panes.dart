import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import '../core/app_theme.dart';
import 'document_image.dart';
import 'document_watermark.dart';
import 'workspace_element_menu.dart';
import 'workspace_links.dart';
import 'workspace_pickers.dart';
import 'workspace_view_model.dart';

class WorkspacePanes extends StatefulWidget {
  const WorkspacePanes({
    super.key,
    required this.vm,
    required this.onAction,
    required this.onError,
    this.editingKey,
    this.mapKey,
    this.mapToolbarKey,
    this.typographyControl,
    this.mapAppearanceController,
    this.mapAppearancePopupKey,
  });
  final WorkspaceViewModel vm;
  final ValueChanged<String> onAction;
  final ValueChanged<Object> onError;
  final GlobalKey? editingKey, mapKey, mapToolbarKey;
  final Widget? typographyControl;
  final MenuController? mapAppearanceController;
  final GlobalKey? mapAppearancePopupKey;
  @override
  State<WorkspacePanes> createState() => _WorkspacePanesState();
}

class _WorkspacePanesState extends State<WorkspacePanes> {
  bool _inspector = false;
  final _mapAppearance = MenuController();
  MenuController get mapAppearance =>
      widget.mapAppearanceController ?? _mapAppearance;
  ValueChanged<MarkdownContextRequest>? _onContextMenu;
  WorkspaceViewModel get vm => widget.vm;
  void _command(VoidCallback action) {
    try {
      action();
    } catch (e) {
      widget.onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceElementMenu(
      vm: vm,
      onAction: widget.onAction,
      onError: widget.onError,
      builder: (onContextMenu) => _panes(onContextMenu),
    );
  }

  Widget _panes(ValueChanged<MarkdownContextRequest> onContextMenu) {
    _onContextMenu = onContextMenu;
    final panes = vm.layout.panes;
    if (panes.length == 1) return _pane(panes.first, false);
    if (vm.layout == WorkspaceLayout.three) {
      return ResizableSplit(
        key: const ValueKey('three'),
        vertical: true,
        initial: .56,
        first: ResizableSplit(
          first: _pane('source', true),
          second: _pane('read', true),
        ),
        second: _pane('map', true),
      );
    }
    return ResizableSplit(
      key: ValueKey(vm.layout),
      first: _pane(panes.first, true),
      second: _pane(panes.last, true),
    );
  }

  Widget _pane(String pane, bool titled) {
    final c = Theme.of(context).colorScheme;
    final title = switch (pane) {
      'source' => context.l10n.markdownSource,
      'read' => context.l10n.bodyPreview,
      'map' => context.l10n.mindMap,
      _ => context.l10n.instantEditing,
    };
    return Focus(
      onFocusChange: (focused) {
        if (focused) vm.activatePane(pane);
      },
      child: Listener(
        onPointerDown: (_) => vm.activatePane(pane),
        child: ColoredBox(
          key: ValueKey('${vm.current.id}-$pane'),
          color: pane == 'map'
              ? c.surface
              : documentTheme(Theme.of(context)).colorScheme.surface,
          child: Column(
            children: [
              if (titled || pane != 'source')
                PanelHeader(
                  title: title,
                  icon: switch (pane) {
                    'map' => 'map',
                    'read' => 'eye',
                    _ => 'edit',
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pane == 'map')
                        WorkspacePickerAnchor(
                          popupKey: widget.mapAppearancePopupKey,
                          vm: vm,
                          picker: WorkspacePicker.map,
                          controller: mapAppearance,
                          child: AppButton(
                            key: const ValueKey('map-appearance-trigger'),
                            label: context.l10n.mapStyleName(vm.map.style),
                            tooltip: context.l10n.mapAppearance,
                            trailingIcon: 'chevron-down',
                            onPressed: () => mapAppearance.isOpen
                                ? mapAppearance.close()
                                : mapAppearance.open(),
                          ),
                        ),
                      if (pane != 'map' &&
                          pane != 'source' &&
                          pane ==
                              vm.layout.panes.firstWhere(
                                (p) => p != 'map' && p != 'source',
                                orElse: () => '',
                              ))
                        widget.typographyControl ?? const SizedBox(),
                      if (titled)
                        AppButton(
                          icon: 'max',
                          tooltip: context.l10n.showPaneOnly(title),
                          height: 25,
                          padding: 4,
                          onPressed: () => vm.setLayout(
                            WorkspaceLayout.values.firstWhere(
                              (l) =>
                                  l.panes.length == 1 && l.panes.first == pane,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: _contentScale(pane, switch (pane) {
                  'source' => MarkdownSourceEditor(
                    onContextMenu: _onContextMenu,
                    key: widget.editingKey,
                    controller: vm.editor,
                    lineNumbers: vm.lineNumbers,
                    typewriter: vm.typewriter,
                    fontSize: vm.editingPreferences.codeSize,
                    editingPreferences: vm.editingPreferences,
                  ),
                  'read' => _DocumentReading(
                    vm: vm,
                    padding: _documentPadding(titled),
                    onContextMenu: _onContextMenu,
                  ),
                  'map' => _mapPane(),
                  _ => MarkdownInstantEditor(
                    onContextMenu: _onContextMenu,
                    imageBuilder: (uri, title, alt) => DocumentImage(
                      uri: uri,
                      documentPath: vm.current.path,
                      alt: alt,
                    ),
                    key: widget.editingKey,
                    controller: vm.editor,
                    labels: context.l10n.editorLabels,
                    typography: vm.typography,
                    compact: vm.compact,
                    typewriter: vm.typewriter,
                    focusMode: vm.focusMode,
                    preferences: vm.markdownPreferences,
                    fontSize: vm.fontSize,
                    editingPreferences: vm.editingPreferences,
                    padding: _documentPadding(titled),
                  ),
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets _documentPadding(bool titled) =>
      vm.viewport == WorkspaceViewport.phone
      ? const EdgeInsets.fromLTRB(25, 28, 25, 70)
      : EdgeInsets.fromLTRB(
          titled ? 34 : 44,
          titled ? 24 : 34,
          titled ? 34 : 44,
          70,
        );

  Widget _contentScale(String pane, Widget child) => pane == 'map'
      ? child
      : Theme(
          data: documentTheme(Theme.of(context)),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.textScalerOf(context).scale(1) * vm.contentZoom,
              ),
            ),
            child: pane == 'source'
                ? child
                : DocumentWatermark(preferences: vm.watermark, child: child),
          ),
        );

  Widget _mapPane() => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        Container(
          key: widget.mapToolbarKey,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppButton(
                        label: context.l10n.addSection,
                        icon: 'plus',
                        height: 26,
                        onPressed: () => _command(
                          () => vm.editor.session.addHeading(
                            vm.selectedHeadingId,
                            child: false,
                            title: context.l10n.newSectionTitle,
                          ),
                        ),
                      ),
                      AppButton(
                        label: context.l10n.childSection,
                        height: 26,
                        onPressed: () => _command(
                          () => vm.editor.session.addHeading(
                            vm.selectedHeadingId,
                            child: true,
                            title: context.l10n.newSectionTitle,
                          ),
                        ),
                      ),
                      AppButton(
                        label: context.l10n.arrange,
                        icon: 'edit',
                        selected: _inspector,
                        height: 26,
                        onPressed: () =>
                            setState(() => _inspector = !_inspector),
                      ),
                      AppButton(
                        label: context.l10n.collapse,
                        icon: 'list',
                        height: 26,
                        onPressed: vm.map.toggleAll,
                      ),
                      AppButton(
                        label: context.l10n.summary,
                        icon: 'gear',
                        height: 26,
                        onPressed: () => widget.onAction('summary'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  key: mapBoundaryKey,
                  child: MindMapView(
                    key: widget.mapKey,
                    controller: vm.map,
                    labels: context.l10n.mapLabels,
                    onSelect: vm.selectNode,
                    onActivate: (node) {
                      vm.selectNode(node);
                      setState(() => _inspector = true);
                    },
                    onMove: (from, to) => _command(() => vm.moveNode(from, to)),
                    onRename: (node, title) =>
                        _command(() => vm.renameNode(node, title)),
                    onCommand: (node, command) async {
                      vm.selectNode(node);
                      if (command == 'delete') {
                        final heading = vm.selectedHeading;
                        if (heading == null) return;
                        final mode = await _confirmDeleteSection(
                          context,
                          heading.title,
                        );
                        if (mounted &&
                            mode != null &&
                            vm.editor.document.heading(heading.id) != null) {
                          _command(
                            () => vm.editor.session.deleteHeading(
                              heading.id,
                              keepContents: mode == 'keep',
                            ),
                          );
                        }
                        return;
                      }
                      _command(
                        () => vm.addMapHeading(
                          child: command == 'child',
                          title: context.l10n.newSectionTitle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_inspector && vm.selectedHeading != null)
                Positioned(
                  right: 10,
                  top: 10,
                  width: constraints.maxWidth < 420
                      ? constraints.maxWidth - 20
                      : 282,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (constraints.maxHeight - 64).clamp(100, 500),
                    ),
                    child: ChapterInspector(
                      key: ValueKey(vm.selectedHeading!.id),
                      vm: vm,
                      onClose: () => setState(() => _inspector = false),
                      onError: widget.onError,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

final mapBoundaryKey = GlobalKey();

class _DocumentReading extends StatefulWidget {
  const _DocumentReading({
    required this.vm,
    required this.padding,
    this.onContextMenu,
  });
  final WorkspaceViewModel vm;
  final EdgeInsets padding;
  final ValueChanged<MarkdownContextRequest>? onContextMenu;
  @override
  State<_DocumentReading> createState() => _DocumentReadingState();
}

class _DocumentReadingState extends State<_DocumentReading>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _list = ListController();
  late final _navigation = MarkdownListNavigator(
    vsync: this,
    list: _list,
    scroll: _scroll,
  );
  String? _lastSelection;
  MarkdownRevealRequest? _lastNavigation;

  @override
  void dispose() {
    _navigation.dispose();
    _list.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm, selected = widget.vm.selectedHeading;
    final blocks = vm.editor.document.blocks;
    final request = vm.editor.navigation.value;
    if (selected?.id != _lastSelection || request != _lastNavigation) {
      _navigation.cancel();
      final offset = request != _lastNavigation
          ? request?.selection.start
          : selected?.header.start;
      _lastSelection = selected?.id;
      _lastNavigation = request;
      final index = blocks.indexWhere(
        (b) => offset != null && b.range.end > offset,
      );
      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_list.isAttached || !_scroll.hasClients) return;
          if (vm.editor.navigation.value != request ||
              vm.selectedHeading?.id != selected?.id) {
            return;
          }
          _navigation.reveal(index);
        });
      }
    }
    return SelectionArea(
      child: Listener(
        onPointerDown: (_) => _navigation.cancel(),
        onPointerSignal: (_) => _navigation.cancel(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: vm.typography.width),
            child: LayoutBuilder(
              builder: (context, constraints) => SuperListView.builder(
                key: PageStorageKey('read:${vm.current.id}'),
                controller: _scroll,
                listController: _list,
                cacheExtent: constraints.maxHeight,
                padding: widget.padding,
                itemCount: blocks.isEmpty ? 1 : blocks.length,
                itemBuilder: (context, index) {
                  if (blocks.isEmpty) return Text(context.l10n.emptyDocument);
                  final block = blocks[index];
                  final reader = MarkdownReader(
                    onMediaContext: (url, image, occurrence, position) {
                      final token = markdownMediaTargets(vm.editor.text, block)
                          .where(
                            (token) =>
                                token.image == image &&
                                token.url == markdownAttributeText(url),
                          )
                          .elementAtOrNull(occurrence);
                      if (token == null) return;
                      widget.onContextMenu?.call(
                        MarkdownContextRequest(
                          offset: token.range.start,
                          position: position,
                          selection: TextSelection.collapsed(
                            offset: token.range.start,
                          ),
                          readOnly: true,
                        ),
                      );
                    },
                    imageBuilder: (uri, title, alt) => DocumentImage(
                      uri: uri,
                      documentPath: vm.current.path,
                      alt: alt,
                    ),
                    key: ValueKey(block.range.start),
                    data: block.range.slice(vm.editor.session.text),
                    labels: context.l10n.editorLabels,
                    typography: vm.typography,
                    compact: vm.compact,
                    fontSize: vm.fontSize,
                    editingPreferences: vm.editingPreferences,
                    preferences: vm.markdownPreferences,
                    onTapLink: (_, href, _) {
                      if (href == '../design/Third-Party-Licenses.html') {
                        showLicensePage(context: context);
                        return;
                      }
                      openWorkspaceLink(vm, href);
                    },
                  );
                  void openContext(Offset position) {
                    final source = vm.editor.text;
                    final tokens =
                        const [
                          MarkdownBlockKind.code,
                          MarkdownBlockKind.math,
                        ].contains(block.kind)
                        ? <MarkdownMediaTarget>[]
                        : markdownMediaTargets(source, block);
                    widget.onContextMenu?.call(
                      MarkdownContextRequest(
                        offset: tokens.length == 1
                            ? tokens.single.range.start
                            : block.range.start,
                        position: position,
                        selection: TextSelection.collapsed(
                          offset: block.range.start,
                        ),
                        readOnly: true,
                      ),
                    );
                  }

                  return GestureDetector(
                    key: ValueKey('read-element-${block.range.start}'),
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapUp: (event) =>
                        openContext(event.globalPosition),
                    onLongPressStart: (event) =>
                        openContext(event.globalPosition),
                    child: reader,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _confirmDeleteSection(BuildContext context, String title) =>
    showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.deleteNamedSection(title),
        actions: [
          AppButton(
            label: context.l10n.cancel,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: context.l10n.keepBody,
            onPressed: () => Navigator.pop(context, 'keep'),
          ),
          AppButton(
            label: context.l10n.deleteWholeSection,
            primary: true,
            onPressed: () => Navigator.pop(context, 'all'),
          ),
        ],
        child: Text(context.l10n.deleteSectionHint),
      ),
    );

class ChapterInspector extends StatefulWidget {
  const ChapterInspector({
    super.key,
    required this.vm,
    required this.onClose,
    required this.onError,
  });
  final WorkspaceViewModel vm;
  final VoidCallback onClose;
  final ValueChanged<Object> onError;
  @override
  State<ChapterInspector> createState() => _ChapterInspectorState();
}

class _ChapterInspectorState extends State<ChapterInspector> {
  late final _title = TextEditingController(
    text: widget.vm.selectedHeading!.title,
  );
  late final _body = TextEditingController(
    text: widget.vm.selectedHeading!.body
        .slice(widget.vm.editor.session.text)
        .trim(),
  );
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _command(VoidCallback action) {
    try {
      action();
    } catch (e) {
      widget.onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm, h = widget.vm.selectedHeading!;
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerLow,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: c.outlineVariant),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelHeader(
              title: context.l10n.sectionArrangement,
              icon: 'edit',
              trailing: AppCloseButton(onPressed: widget.onClose),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.sectionTitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        'H${h.level}',
                        style: TextStyle(fontSize: 12, color: c.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _title,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 3,
                    runSpacing: 5,
                    children: [
                      for (final entry in <(String, VoidCallback)>[
                        (
                          context.l10n.moveUp,
                          () => vm.editor.session.moveHeading(h.id, -1),
                        ),
                        (
                          context.l10n.moveDown,
                          () => vm.editor.session.moveHeading(h.id, 1),
                        ),
                        (
                          context.l10n.promote,
                          () => vm.editor.session.changeLevel(h.id, -1),
                        ),
                        (
                          context.l10n.demote,
                          () => vm.editor.session.changeLevel(h.id, 1),
                        ),
                        (
                          context.l10n.sibling,
                          () => vm.editor.session.addHeading(
                            h.id,
                            child: false,
                            title: context.l10n.newSectionTitle,
                          ),
                        ),
                        (
                          context.l10n.child,
                          () => vm.editor.session.addHeading(
                            h.id,
                            child: true,
                            title: context.l10n.newSectionTitle,
                          ),
                        ),
                      ])
                        AppButton(
                          label: entry.$1,
                          bordered: true,
                          height: 26,
                          onPressed: () => _command(entry.$2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    context.l10n.sectionBody,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _body,
                    minLines: 3,
                    maxLines: 7,
                    style: const TextStyle(fontSize: 11.5, height: 1.7),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.sectionBodyHint,
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      AppButton(
                        label: context.l10n.deleteSection,
                        onPressed: () async {
                          final mode = await _confirmDeleteSection(
                            context,
                            h.title,
                          );
                          if (mode != null && mounted) {
                            _command(
                              () => vm.editor.session.deleteHeading(
                                h.id,
                                keepContents: mode == 'keep',
                              ),
                            );
                          }
                        },
                      ),
                      const Spacer(),
                      AppButton(
                        label: context.l10n.apply,
                        primary: true,
                        onPressed: () => _command(() {
                          // Body first: renaming changes the derived heading identity.
                          vm.editor.session.replaceBody(h.id, _body.text);
                          vm.editor.session.renameHeading(h.id, _title.text);
                          vm.selectedHeadingId = vm.editor.document.headings
                              .where((n) => n.header.start == h.header.start)
                              .firstOrNull
                              ?.id;
                          widget.onClose();
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResizableSplit extends StatefulWidget {
  const ResizableSplit({
    super.key,
    required this.first,
    required this.second,
    this.vertical = false,
    this.initial = .5,
  });
  final Widget first, second;
  final bool vertical;
  final double initial;
  @override
  State<ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<ResizableSplit> {
  late double _ratio = widget.initial;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final extent = widget.vertical
          ? constraints.maxHeight
          : constraints.maxWidth;
      final first = (extent - 5) * _ratio;
      final handle = MouseRegion(
        cursor: widget.vertical
            ? SystemMouseCursors.resizeUpDown
            : SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => setState(
            () => _ratio =
                (_ratio +
                        (widget.vertical
                                ? details.delta.dy
                                : details.delta.dx) /
                            extent)
                    .clamp(.2, .8),
          ),
          child: SizedBox(
            width: widget.vertical ? double.infinity : 5,
            height: widget.vertical ? 5 : double.infinity,
            child: Center(
              child: Container(
                width: widget.vertical ? double.infinity : 1,
                height: widget.vertical ? 1 : double.infinity,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      );
      final children = [
        SizedBox(
          width: widget.vertical ? null : first,
          height: widget.vertical ? first : null,
          child: widget.first,
        ),
        handle,
        Expanded(child: widget.second),
      ];
      return widget.vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            );
    },
  );
}
