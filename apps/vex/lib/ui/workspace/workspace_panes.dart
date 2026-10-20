import 'dart:async';

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
    this.formattingControl,
    this.mapAppearanceController,
    this.mapAppearancePopupKey,
  });
  final WorkspaceViewModel vm;
  final ValueChanged<String> onAction;
  final ValueChanged<Object> onError;
  final GlobalKey? editingKey, mapKey, mapToolbarKey;
  final Widget? typographyControl;
  final Widget? formattingControl;
  final MenuController? mapAppearanceController;
  final GlobalKey? mapAppearancePopupKey;
  @override
  State<WorkspacePanes> createState() => _WorkspacePanesState();
}

class _WorkspacePanesState extends State<WorkspacePanes> {
  bool _inspector = false;
  (bool, bool, bool)? _summaryVisibility;
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
        initial: vm.windowSize.height < 600 ? .44 : .5,
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
      'source' => context.l10n.source,
      'read' => context.l10n.read,
      'map' => context.l10n.mindMap,
      _ => context.l10n.instantEditing,
    };
    return Focus(
      onFocusChange: (focused) {
        if (!focused) return;
        // Focus reparenting during a layout/theme change can run in build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && vm.layout.panes.contains(pane)) vm.activatePane(pane);
        });
      },
      child: Listener(
        onPointerDown: (_) => vm.activatePane(pane),
        onPointerSignal: (_) => vm.activatePane(pane),
        child: ColoredBox(
          key: ValueKey('${vm.current.id}-$pane'),
          color: pane == 'map'
              ? c.surface
              : documentTheme(Theme.of(context)).colorScheme.surface,
          child: Column(
            children: [
              if (titled || pane != 'source')
                PanelHeader(
                  height: 36,
                  title: title,
                  backgroundColor: titled && vm.activePane == pane
                      ? c.primary.withValues(alpha: .045)
                      : null,
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
                            label: context.l10n.mapAppearance,
                            fontSize: 12,
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
              if (pane == 'source' || pane == 'instant')
                ?widget.formattingControl,
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
          child: LayoutBuilder(
            builder: (context, toolbar) {
              final only = !vm.paragraphs && !vm.lists && !vm.blocks;
              final left = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: context.l10n.childSection,
                    icon: 'plus',
                    fontSize: 11,
                    height: 26,
                    padding: 6,
                    onPressed: () => _command(
                      () => vm.addMapHeading(
                        child: true,
                        title: context.l10n.newSectionTitle,
                      ),
                    ),
                  ),
                  AppButton(
                    label: context.l10n.sibling,
                    icon: 'plus',
                    fontSize: 11,
                    height: 26,
                    padding: 6,
                    onPressed: () => _command(
                      () => vm.addMapHeading(
                        child: false,
                        title: context.l10n.newSectionTitle,
                      ),
                    ),
                  ),
                  AppButton(
                    key: const ValueKey('map-headings-only'),
                    label: context.l10n.mapHeadingsOnly,
                    selected: only,
                    fontSize: 11,
                    height: 26,
                    padding: 6,
                    onPressed: () {
                      if (!only) {
                        _summaryVisibility = (
                          vm.paragraphs,
                          vm.lists,
                          vm.blocks,
                        );
                      }
                      final saved = _summaryVisibility ?? (true, true, false);
                      vm.setSummary(
                        paragraphs: only && saved.$1,
                        lists: only && saved.$2,
                        blocks: only && saved.$3,
                      );
                    },
                  ),
                ],
              );
              final right = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: only
                        ? context.l10n.mapHeadingsOnly
                        : context.l10n.mapSummaryLabel(vm.summaryLength),
                    icon: 'gear',
                    fontSize: 11,
                    height: 26,
                    padding: 6,
                    onPressed: () => widget.onAction('summary'),
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  AppButton(
                    label: context.l10n.collapse,
                    icon: 'list',
                    fontSize: 11,
                    height: 26,
                    padding: 6,
                    onPressed: vm.map.toggleAll,
                  ),
                  AppButton(
                    label: context.l10n.mapCompareSource,
                    icon: 'columns',
                    fontSize: 11,
                    height: 26,
                    padding: 6,
                    selected: vm.layout.panes.contains('source'),
                    onPressed: () => vm.setLayout(
                      vm.layout.panes.contains('source')
                          ? WorkspaceLayout.map
                          : WorkspaceLayout.sourceMap,
                    ),
                  ),
                  AppButton(
                    icon: 'edit',
                    label: context.l10n.sectionBody,
                    tooltip: context.l10n.arrange,
                    selected: vm.viewport == WorkspaceViewport.phone
                        ? _inspector
                        : vm.structure &&
                              vm.auxiliary == WorkspaceAuxiliary.chapter,
                    height: 26,
                    padding: 6,
                    onPressed: () {
                      if (vm.viewport == WorkspaceViewport.phone) {
                        setState(() => _inspector = !_inspector);
                      } else if (vm.structure &&
                          vm.auxiliary == WorkspaceAuxiliary.chapter) {
                        vm.showStructure(false);
                      } else {
                        vm.showAuxiliary(WorkspaceAuxiliary.chapter);
                      }
                    },
                  ),
                ],
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: toolbar.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [left, right],
                  ),
                ),
              );
            },
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
                    onSelect: (node) {
                      vm.selectNode(node);
                      if (vm.viewport == WorkspaceViewport.phone) {
                        setState(() => _inspector = true);
                      } else {
                        vm.showAuxiliary(WorkspaceAuxiliary.chapter);
                      }
                    },
                    onActivate: (node) {
                      vm.selectNode(node);
                      if (vm.viewport == WorkspaceViewport.phone) {
                        setState(() => _inspector = true);
                      } else {
                        vm.showAuxiliary(WorkspaceAuxiliary.chapter);
                      }
                    },
                    onMove: (from, to) => _command(() => vm.moveNode(from, to)),
                    movePreview: (from, to) {
                      final preview = vm.movePreview(from, to);
                      return preview == null
                          ? null
                          : context.l10n.mapMovePreview(
                              preview.title,
                              preview.level,
                              preview.children,
                              preview.characters,
                            );
                    },
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
                            () => vm.chapterEdit(
                              () => vm.editor.session.deleteHeading(
                                heading.id,
                                keepContents: mode == 'keep',
                              ),
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
              Positioned(
                left: 16,
                top: 13,
                child: IgnorePointer(
                  child: Row(
                    children: [
                      for (final label in [
                        context.l10n.heading,
                        context.l10n.mapContentSummary,
                      ]) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 15),
                      ],
                    ],
                  ),
                ),
              ),
              if (vm.editor.document.headings.isEmpty)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 56,
                  child: IgnorePointer(
                    child: Text(
                      context.l10n.mapEmptyHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              if (vm.canUndoChapter)
                Positioned(
                  left: 12,
                  bottom: 54,
                  child: Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(5),
                    child: AppButton(
                      key: const ValueKey('undo-chapter'),
                      label: context.l10n.undoChapter,
                      icon: 'undo',
                      fontSize: 11,
                      onPressed: vm.undoChapter,
                    ),
                  ),
                ),
              if (constraints.maxWidth >= 680)
                Positioned(
                  left: 116,
                  bottom: 14,
                  child: IgnorePointer(
                    child: Text(
                      context.l10n.mapNavigationHint,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              if (vm.viewport == WorkspaceViewport.phone &&
                  _inspector &&
                  vm.selectedHeading != null)
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
  MarkdownRevealRequest? _lastNavigation;
  final _searchMatchKey = GlobalKey();
  // 定位后的短暂高亮（与原型 locate 1.3s 渐隐一致）：TOC、脚注、大纲共用。
  int? _flashIndex;
  Timer? _flashTimer;

  void _flashBlock(int index) {
    _flashTimer?.cancel();
    setState(() => _flashIndex = index);
    _flashTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _flashIndex = null);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _navigation.dispose();
    _list.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final blocks = vm.editor.document.blocks;
    final request = vm.editor.navigation.value;
    if (request != _lastNavigation) {
      _navigation.cancel();
      final offset = request?.selection.start;
      _lastNavigation = request;
      final index = blocks.indexWhere(
        (b) => offset != null && b.range.end > offset,
      );
      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_list.isAttached || !_scroll.hasClients) return;
          if (vm.editor.navigation.value != request ||
              vm.editor.viewport.value != null) {
            return;
          }
          if (offset! <= blocks[index].range.start) {
            _navigation.reveal(index);
          } else {
            void reveal() => MarkdownListViewport.write(
              offset.toDouble(),
              _list,
              _scroll,
              vm.editor.document.blocks,
              alignment: .08,
            );
            reveal();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  vm.editor.navigation.value == request &&
                  vm.editor.viewport.value == null) {
                reveal();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted &&
                      vm.editor.navigation.value == request &&
                      vm.editor.viewport.value == null) {
                    MarkdownSearchHighlight.reveal(_searchMatchKey);
                  }
                });
                WidgetsBinding.instance.ensureVisualUpdate();
              }
            });
            WidgetsBinding.instance.ensureVisualUpdate();
          }
          _flashBlock(index);
        });
      }
    }
    return MarkdownViewportSync(
      controller: vm.editor,
      scroll: _scroll,
      readPosition: () =>
          MarkdownListViewport.read(_list, _scroll, vm.editor.document.blocks),
      writePosition: (offset) => MarkdownListViewport.write(
        offset,
        _list,
        _scroll,
        vm.editor.document.blocks,
      ),
      child: SelectionArea(
        onSelectionChanged: (selection) =>
            vm.setReadingSelection(selection?.plainText),
        child: Listener(
          onPointerDown: (_) => _navigation.cancel(),
          onPointerSignal: (_) => _navigation.cancel(),
          child: Align(
            alignment: Alignment.topCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _navigation.preservePosition((
                  constraints.biggest,
                  vm.typography,
                  vm.compact,
                  vm.fontSize,
                  vm.editingPreferences,
                  vm.markdownPreferences,
                  MediaQuery.textScalerOf(context),
                ), contentKey: vm.editor.document);
                return SuperListView.builder(
                  key: PageStorageKey('read:${vm.current.id}'),
                  controller: _scroll,
                  listController: _list,
                  cacheExtent: constraints.maxHeight,
                  padding: widget.padding.copyWith(
                    left: ((constraints.maxWidth - 820) / 2).clamp(
                      widget.padding.left,
                      double.infinity,
                    ),
                    right: ((constraints.maxWidth - 820) / 2).clamp(
                      widget.padding.right,
                      double.infinity,
                    ),
                  ),
                  itemCount: blocks.isEmpty ? 1 : blocks.length,
                  itemBuilder: (context, index) {
                    if (blocks.isEmpty) return Text(context.l10n.emptyDocument);
                    final block = blocks[index];
                    final match = vm.editor.searchMatchFor(block.range);
                    final reader = MarkdownReader(
                      documentSource: vm.editor.text,
                      document: vm.editor.document,
                      onMediaContext: (url, image, occurrence, position) {
                        final token =
                            markdownMediaTargets(vm.editor.text, block)
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

                    // 空行规则（与 Typora 相符）：块间第一个空行不产生额外间距，
                    // 每多一个空行则补一行正文高度——保留作者的疏密意图。
                    var extraBlankLines = 0;
                    if (index > 0) {
                      final separator =
                          block.range.start <= blocks[index - 1].range.end
                          ? ''
                          : vm.editor.text.substring(
                              blocks[index - 1].range.end,
                              block.range.start,
                            );
                      extraBlankLines = separator.isEmpty
                          ? 0
                          : (separator.split('\n').length - 3).clamp(0, 6);
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: index == _flashIndex
                            ? Theme.of(context).colorScheme.primary
                                  .withValues(alpha: .16)
                            : Colors.transparent,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (extraBlankLines > 0)
                            SizedBox(height: extraBlankLines * vm.fontSize),
                          GestureDetector(
                            key: ValueKey('read-element-${block.range.start}'),
                            behavior: HitTestBehavior.translucent,
                            onSecondaryTapUp: (event) =>
                                openContext(event.globalPosition),
                            onLongPressStart: (event) =>
                                openContext(event.globalPosition),
                            child: MarkdownSearchHighlight(
                              key: match == null ? null : _searchMatchKey,
                              match: match,
                              child: reader,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
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
    this.embedded = false,
  });
  final WorkspaceViewModel vm;
  final VoidCallback onClose;
  final ValueChanged<Object> onError;
  final bool embedded;
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
  late String _syncedTitle = widget.vm.selectedHeading!.title;
  late String _syncedBody = _body.text;

  @override
  void didUpdateWidget(covariant ChapterInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final heading = widget.vm.selectedHeading;
    if (heading == null) return;
    final body = heading.body.slice(widget.vm.editor.text).trim();
    if (heading.title != _syncedTitle) {
      _title.text = _syncedTitle = heading.title;
    }
    if (body != _syncedBody) _body.text = _syncedBody = body;
  }

  void _syncTitle(String text) {
    final vm = widget.vm, heading = widget.vm.selectedHeading;
    if (heading == null || text.trim().isEmpty) return;
    _syncedTitle = text.trim();
    _command(() {
      vm.editor.session.renameHeading(heading.id, text);
      vm.selectedHeadingId = vm.editor.document.headings
          .where((h) => h.header.start == heading.header.start)
          .firstOrNull
          ?.id;
    });
  }

  void _syncBody(String text) {
    final vm = widget.vm, heading = widget.vm.selectedHeading;
    if (heading == null) return;
    _syncedBody = text.trim();
    _command(() => vm.editor.session.replaceBody(heading.id, text));
  }

  void _changeLevel(int delta) {
    final vm = widget.vm, heading = widget.vm.selectedHeading;
    if (heading == null) return;
    vm.editor.session.changeLevel(heading.id, delta);
    vm.selectedHeadingId = vm.editor.document.headings
        .where((h) => h.header.start == heading.header.start)
        .firstOrNull
        ?.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _command(VoidCallback action) {
    try {
      widget.vm.chapterEdit(action);
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
      elevation: widget.embedded ? 0 : 5,
      shape: widget.embedded
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: BorderSide(color: c.outlineVariant),
            ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.embedded)
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
                          key: const ValueKey('chapter-title-input'),
                          controller: _title,
                          onChanged: widget.embedded ? _syncTitle : null,
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
                        (context.l10n.promote, () => _changeLevel(-1)),
                        (context.l10n.demote, () => _changeLevel(1)),
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
                  if (widget.embedded) ...[
                    AppButton(
                      label: context.l10n.revealSection,
                      icon: 'edit',
                      key: const ValueKey('chapter-reveal'),
                      fontSize: 12,
                      onPressed: () {
                        if (!vm.layout.panes.any(
                          (pane) => pane == 'source' || pane == 'instant',
                        )) {
                          vm.setLayout(
                            vm.layout.panes.contains('map')
                                ? WorkspaceLayout.instantMap
                                : WorkspaceLayout.instant,
                          );
                        }
                        vm.selectHeading(h);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.l10n.sectionBody,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    key: const ValueKey('chapter-body-input'),
                    controller: _body,
                    onChanged: widget.embedded ? _syncBody : null,
                    minLines: 3,
                    maxLines: widget.embedded ? null : 7,
                    style: const TextStyle(fontSize: 11.5, height: 1.7),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.embedded
                        ? context.l10n.chapterBodyAutosaveHint
                        : context.l10n.sectionBodyHint,
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
                      if (widget.embedded)
                        AppButton(
                          label: context.l10n.undo,
                          onPressed: vm.canUndoChapter ? vm.undoChapter : null,
                        )
                      else
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
