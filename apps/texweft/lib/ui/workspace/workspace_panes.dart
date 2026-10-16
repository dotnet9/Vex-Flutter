import 'package:flutter/material.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:texweft_mindmap/texweft_mindmap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/workspace.dart';
import '../core/app_widgets.dart';
import 'workspace_view_model.dart';

class WorkspacePanes extends StatefulWidget {
  const WorkspacePanes({
    super.key,
    required this.vm,
    required this.onAction,
    required this.onError,
  });
  final WorkspaceViewModel vm;
  final ValueChanged<String> onAction;
  final ValueChanged<Object> onError;
  @override
  State<WorkspacePanes> createState() => _WorkspacePanesState();
}

class _WorkspacePanesState extends State<WorkspacePanes> {
  bool _inspector = false;
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
      'source' => 'Markdown 源码',
      'read' => '正文预览',
      'map' => '思维导图',
      _ => '即时编辑',
    };
    return ColoredBox(
      key: ValueKey('${vm.current.id}-$pane'),
      color: pane == 'source' ? c.surfaceContainer : c.surface,
      child: Column(
        children: [
          if (titled)
            PanelHeader(
              title: title,
              icon: switch (pane) {
                'map' => 'map',
                'read' => 'eye',
                _ => 'edit',
              },
              trailing: AppButton(
                icon: 'max',
                tooltip: '单独显示$title',
                height: 25,
                padding: 4,
                onPressed: () => vm.setLayout(
                  WorkspaceLayout.values.firstWhere(
                    (l) => l.panes.length == 1 && l.panes.first == pane,
                  ),
                ),
              ),
            ),
          Expanded(
            child: switch (pane) {
              'source' => MarkdownSourceEditor(
                controller: vm.editor,
                lineNumbers: vm.lineNumbers,
                fontSize: 12,
              ),
              'read' => _DocumentReading(vm: vm),
              'map' => _mapPane(),
              _ => MarkdownInstantEditor(
                controller: vm.editor,
                typography: vm.typography,
                compact: vm.compact,
                fontSize: vm.fontSize,
                padding: EdgeInsets.fromLTRB(
                  titled ? 34 : 44,
                  titled ? 24 : 34,
                  titled ? 34 : 44,
                  70,
                ),
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _mapPane() => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        Container(
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
                        label: '新增章节',
                        icon: 'plus',
                        height: 26,
                        onPressed: () => _command(
                          () => vm.editor.session.addHeading(
                            vm.selectedHeadingId,
                            child: false,
                          ),
                        ),
                      ),
                      AppButton(
                        label: '子章节',
                        height: 26,
                        onPressed: () => _command(
                          () => vm.editor.session.addHeading(
                            vm.selectedHeadingId,
                            child: true,
                          ),
                        ),
                      ),
                      AppButton(
                        label: '编排',
                        icon: 'edit',
                        selected: _inspector,
                        height: 26,
                        onPressed: () =>
                            setState(() => _inspector = !_inspector),
                      ),
                      AppButton(
                        label: '折叠',
                        icon: 'list',
                        height: 26,
                        onPressed: vm.map.toggleAll,
                      ),
                      AppButton(
                        label: '摘要设置',
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
                    controller: vm.map,
                    onSelect: vm.selectNode,
                    onActivate: (node) {
                      vm.selectNode(node);
                      setState(() => _inspector = true);
                    },
                    onMove: (from, to) => _command(() => vm.moveNode(from, to)),
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
  const _DocumentReading({required this.vm});
  final WorkspaceViewModel vm;
  @override
  State<_DocumentReading> createState() => _DocumentReadingState();
}

class _DocumentReadingState extends State<_DocumentReading> {
  final _anchors = <int, GlobalKey>{};
  String? _lastSelection;
  @override
  Widget build(BuildContext context) {
    final vm = widget.vm, selected = widget.vm.selectedHeading;
    if (selected?.id != _lastSelection) {
      _lastSelection = selected?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _anchors[selected?.header.start]?.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 200),
            alignment: .08,
          );
        }
      });
    }
    final valid = vm.editor.document.blocks.map((b) => b.range.start).toSet();
    _anchors.removeWhere((start, _) => !valid.contains(start));
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: vm.typography.width),
          child: Padding(
            padding: EdgeInsets.fromLTRB(44, 34, 44, 70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final block in vm.editor.document.blocks)
                  Padding(
                    key: _anchors.putIfAbsent(block.range.start, GlobalKey.new),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MarkdownReader(
                      data: block.range.slice(vm.editor.session.text),
                      typography: vm.typography,
                      compact: vm.compact,
                      fontSize: vm.presentation
                          ? vm.fontSize * 1.5
                          : vm.fontSize,
                      onTapLink: (_, href, _) {
                        final uri = Uri.tryParse(href ?? '');
                        if (uri != null &&
                            ['https', 'http', 'mailto'].contains(uri.scheme)) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                if (vm.editor.session.text.isEmpty) const Text('这篇文档还是空白。'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
              title: '章节编排',
              icon: 'edit',
              trailing: AppButton(
                icon: 'x',
                onPressed: widget.onClose,
                height: 24,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('章节标题', style: TextStyle(fontSize: 11)),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        'H${h.level}',
                        style: TextStyle(fontSize: 11, color: c.primary),
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
                        ('上移', () => vm.editor.session.moveHeading(h.id, -1)),
                        ('下移', () => vm.editor.session.moveHeading(h.id, 1)),
                        ('升级', () => vm.editor.session.changeLevel(h.id, -1)),
                        ('降级', () => vm.editor.session.changeLevel(h.id, 1)),
                        (
                          '同级',
                          () =>
                              vm.editor.session.addHeading(h.id, child: false),
                        ),
                        (
                          '子级',
                          () => vm.editor.session.addHeading(h.id, child: true),
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
                  const Text('本节正文', style: TextStyle(fontSize: 11)),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _body,
                    minLines: 3,
                    maxLines: 7,
                    style: const TextStyle(fontSize: 11.5, height: 1.7),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '只编辑本节正文，子章节会完整保留。',
                    style: TextStyle(fontSize: 10, color: c.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      AppButton(
                        label: '删除章节',
                        onPressed: () async {
                          final mode = await showDialog<String>(
                            context: context,
                            builder: (context) => AppDialog(
                              title: '删除「${h.title}」',
                              actions: [
                                AppButton(
                                  label: '取消',
                                  onPressed: () => Navigator.pop(context),
                                ),
                                AppButton(
                                  label: '保留正文',
                                  onPressed: () =>
                                      Navigator.pop(context, 'keep'),
                                ),
                                AppButton(
                                  label: '删除整节',
                                  primary: true,
                                  onPressed: () =>
                                      Navigator.pop(context, 'all'),
                                ),
                              ],
                              child: const Text(
                                '可以连同正文和子章节一起删除，或只移除标题。此操作可撤销。',
                              ),
                            ),
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
                        label: '应用',
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
