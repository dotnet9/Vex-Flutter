import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'labels.dart';
import 'layout.dart';

typedef MindMapNodeBuilder = Widget Function(
  BuildContext context,
  MindMapNode node,
  bool selected,
);

class MindMapView extends StatefulWidget {
  const MindMapView({
    super.key,
    required this.controller,
    this.onSelect,
    this.onActivate,
    this.onMove,
    this.onRename,
    this.nodeBuilder,
    this.showControls = true,
    this.enableKeyboardNavigation = true,
    this.overviewThreshold = .2,
    this.labels = const MindMapLabels(),
  });
  final MindMapLabels labels;
  final MindMapController controller;
  final ValueChanged<MindMapNode>? onSelect, onActivate;
  final void Function(String sourceId, String targetId)? onMove;
  final void Function(MindMapNode node, String title)? onRename;
  final MindMapNodeBuilder? nodeBuilder;
  final bool showControls, enableKeyboardNavigation;

  /// Below this scale, large maps paint cards without unreadable text or per-node
  /// drag widgets. Use zero to keep a custom node builder at every scale.
  final double overviewThreshold;
  @override
  State<MindMapView> createState() => _MindMapViewState();
}

class _MindMapViewState extends State<MindMapView> {
  MindMapController get controller => widget.controller;
  MindMapLabels get labels => widget.labels;
  ValueChanged<MindMapNode>? get onSelect => widget.onSelect;
  ValueChanged<MindMapNode>? get onActivate => widget.onActivate;
  void Function(String, String)? get onMove => widget.onMove;
  MindMapNodeBuilder? get nodeBuilder => widget.nodeBuilder;
  bool get enableKeyboardNavigation => widget.enableKeyboardNavigation;
  bool get showControls => widget.showControls;
  double get overviewThreshold => widget.overviewThreshold;
  final _title = TextEditingController();
  final _titleFocus = FocusNode(), _canvasFocus = FocusNode();
  MindMapNode? _editing;

  void _activate(MindMapNode node) {
    controller.select(node.id);
    onSelect?.call(node);
    if (widget.onRename == null || node.summary) {
      onActivate?.call(node);
      return;
    }
    _commit();
    setState(() {
      _editing = node;
      _title.text = node.title;
    });
    _title.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _title.text.length,
    );
    _titleFocus.requestFocus();
  }

  void _commit({bool cancel = false}) {
    final node = _editing;
    if (node == null) return;
    setState(() => _editing = null);
    final title = _title.text.trim();
    if (!cancel && title.isNotEmpty && title != node.title) {
      widget.onRename?.call(node, title);
    }
    _canvasFocus.requestFocus();
  }

  @override
  void didUpdateWidget(covariant MindMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _editing = null;
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    _canvasFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = constraints.biggest;
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final layout = controller.layout,
              color = Theme.of(context).colorScheme;
          if (controller.fitRequested) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && controller.fitRequested) {
                controller.fit(viewport);
              }
            });
          }
          return Focus(
            focusNode: _canvasFocus,
            autofocus: false,
            onKeyEvent: (_, event) {
              if (!enableKeyboardNavigation || _editing != null) {
                return KeyEventResult.ignored;
              }
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final node = layout.nodes[controller.selectedId];
              if (node == null) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.f2) {
                _activate(node);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                  node.children.isNotEmpty) {
                if (controller.collapsed.contains(node.id)) {
                  controller.toggle(node.id);
                }
                controller.select(node.children.first.id);
                onSelect?.call(node.children.first);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                final parent = layout.nodes.values
                    .where((p) => p.children.any((c) => c.id == node.id))
                    .firstOrNull;
                if (parent != null) {
                  controller.select(parent.id);
                  onSelect?.call(parent);
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(color.outlineVariant),
                  ),
                ),
                Positioned.fill(
                  child: InteractiveViewer.builder(
                    transformationController: controller.transformation,
                    minScale: controller.minimumScaleFor(viewport),
                    maxScale: 3,
                    boundaryMargin: const EdgeInsets.all(800),
                    builder: (context, quad) {
                      final points = [
                        quad.point0,
                        quad.point1,
                        quad.point2,
                        quad.point3,
                      ];
                      final visible = Rect.fromLTRB(
                        points.map((p) => p.x).reduce(math.min),
                        points.map((p) => p.y).reduce(math.min),
                        points.map((p) => p.x).reduce(math.max),
                        points.map((p) => p.y).reduce(math.max),
                      ).inflate(100 / controller.scale);
                      final overview =
                          layout.nodes.length > 300 &&
                          controller.scale < overviewThreshold;
                      var doubleTapPosition = Offset.zero;
                      void selectAt(Offset point, {bool activate = false}) {
                        for (final entry in layout.rects.entries) {
                          if (!entry.value.contains(point)) continue;
                          final node = layout.nodes[entry.key]!;
                          controller.select(node.id);
                          if (activate) {
                            _activate(node);
                          } else {
                            onSelect?.call(node);
                          }
                          return;
                        }
                      }

                      return SizedBox(
                        width: layout.size.width,
                        height: layout.size.height,
                        child: GestureDetector(
                          behavior: overview
                              ? HitTestBehavior.opaque
                              : HitTestBehavior.deferToChild,
                          onTapUp: overview
                              ? (details) => selectAt(details.localPosition)
                              : null,
                          onDoubleTapDown: overview
                              ? (details) =>
                                    doubleTapPosition = details.localPosition
                              : null,
                          onDoubleTap: overview
                              ? () =>
                                    selectAt(doubleTapPosition, activate: true)
                              : null,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _EdgesPainter(
                                    layout,
                                    color.primary,
                                    visible,
                                  ),
                                ),
                              ),
                              if (overview)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _OverviewPainter(
                                      layout,
                                      color,
                                      controller.selectedId,
                                      controller.root.id,
                                      visible,
                                    ),
                                  ),
                                )
                              else
                                for (final entry in layout.rects.entries)
                                  if (entry.value.overlaps(visible))
                                    AnimatedPositioned.fromRect(
                                      key: ValueKey(entry.key),
                                      rect: entry.value,
                                      duration:
                                          MediaQuery.disableAnimationsOf(
                                            context,
                                          )
                                          ? Duration.zero
                                          : const Duration(milliseconds: 180),
                                      curve: Curves.easeOutCubic,
                                      child: _node(
                                        context,
                                        layout.nodes[entry.key]!,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (showControls)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Material(
                      color: color.surface,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: labels.zoomOut,
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                controller.zoom(1 / 1.15, viewport),
                            icon: const Icon(Icons.remove, size: 16),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${(controller.scale * 100).round()}%',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          IconButton(
                            tooltip: labels.zoomIn,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => controller.zoom(1.15, viewport),
                            icon: const Icon(Icons.add, size: 16),
                          ),
                          IconButton(
                            tooltip: labels.fitCanvas,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => controller.fit(viewport),
                            icon: const Icon(Icons.fit_screen, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
  Widget _node(BuildContext context, MindMapNode node) {
    final color = Theme.of(context).colorScheme;
    final selected = controller.selectedId == node.id,
        root = node.id == controller.root.id;
    final content =
        nodeBuilder?.call(context, node, selected) ??
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: root
                ? color.primary
                : selected
                ? color.primaryContainer
                : node.summary
                ? color.surface
                : color.surfaceContainerLow,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? color.primary : color.outlineVariant,
              width: selected ? 1.5 : .7,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (node.subtitle != null)
                Text(
                  node.subtitle!,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9,
                    color: root
                        ? color.onPrimary.withValues(alpha: .75)
                        : color.onSurfaceVariant,
                  ),
                ),
              if (_editing?.id == node.id)
                Focus(
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      _commit(cancel: true);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    key: const ValueKey('mindmap-inline-title'),
                    controller: _title,
                    focusNode: _titleFocus,
                    onTapOutside: (_) => _commit(),
                    onSubmitted: (_) => _commit(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: root ? color.onPrimary : color.onSurface,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 3),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                )
              else
                Text(
                  node.title,
                  maxLines: node.summary ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: node.summary ? 12 : 14,
                    fontWeight: node.summary
                        ? FontWeight.normal
                        : FontWeight.w600,
                    color: root ? color.onPrimary : color.onSurface,
                  ),
                ),
            ],
          ),
        );
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          details.data != node.id && onMove != null,
      onAcceptWithDetails: (details) => onMove?.call(details.data, node.id),
      builder: (context, candidates, rejected) => Semantics(
        button: true,
        selected: selected,
        label: node.title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _canvasFocus.requestFocus();
            controller.select(node.id);
            onSelect?.call(node);
          },
          onDoubleTap: () => _activate(node),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: LongPressDraggable<String>(
                  data: node.id,
                  maxSimultaneousDrags:
                      _editing != null || onMove == null || root || node.summary
                      ? 0
                      : 1,
                  feedback: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(width: 176, height: 66, child: content),
                  ),
                  childWhenDragging: Opacity(opacity: .35, child: content),
                  child: content,
                ),
              ),
              if (candidates.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: color.primary, width: 3),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              if (node.children.isNotEmpty)
                Positioned(
                  right: -11,
                  top: 23,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: IconButton.filledTonal(
                      padding: EdgeInsets.zero,
                      tooltip: controller.collapsed.contains(node.id)
                          ? labels.expand
                          : labels.collapse,
                      onPressed: () => controller.toggle(node.id),
                      icon: Icon(
                        controller.collapsed.contains(node.id)
                            ? Icons.add
                            : Icons.remove,
                        size: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewPainter extends CustomPainter {
  const _OverviewPainter(
    this.layout,
    this.colors,
    this.selectedId,
    this.rootId,
    this.visible,
  );
  final MindMapLayout layout;
  final ColorScheme colors;
  final String? selectedId;
  final String rootId;
  final Rect visible;
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint(), border = Paint()..style = PaintingStyle.stroke;
    for (final entry in layout.rects.entries) {
      if (!entry.value.overlaps(visible)) continue;
      final selected = entry.key == selectedId;
      fill.color = entry.key == rootId
          ? colors.primary
          : selected
          ? colors.primaryContainer
          : colors.surfaceContainerLow;
      border.color = selected ? colors.primary : colors.outlineVariant;
      border.strokeWidth = selected ? 2 : .7;
      final card = RRect.fromRectAndRadius(
        entry.value,
        const Radius.circular(7),
      );
      canvas.drawRRect(card, fill);
      canvas.drawRRect(card, border);
    }
  }

  @override
  bool shouldRepaint(_OverviewPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.colors != colors ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.visible != visible ||
      oldDelegate.rootId != rootId;
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .65);
    for (var x = 8.0; x < size.width; x += 20) {
      for (var y = 8.0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), .65, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.color != color;
}

class _EdgesPainter extends CustomPainter {
  const _EdgesPainter(this.layout, this.color, this.visible);
  final MindMapLayout layout;
  final Color color;
  final Rect visible;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final path in layout.paths) {
      if (!path.getBounds().inflate(2).overlaps(visible)) continue;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgesPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.color != color ||
      oldDelegate.visible != visible;
}
