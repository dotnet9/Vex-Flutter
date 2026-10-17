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

class MindMapView extends StatelessWidget {
  const MindMapView({
    super.key,
    required this.controller,
    this.onSelect,
    this.onActivate,
    this.onMove,
    this.nodeBuilder,
    this.showControls = true,
    this.labels = const MindMapLabels(),
  });
  final MindMapLabels labels;
  final MindMapController controller;
  final ValueChanged<MindMapNode>? onSelect, onActivate;
  final void Function(String sourceId, String targetId)? onMove;
  final MindMapNodeBuilder? nodeBuilder;
  final bool showControls;
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
            autofocus: false,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final node = layout.nodes[controller.selectedId];
              if (node == null) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.f2) {
                onActivate?.call(node);
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
                    minScale: .15,
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
                      return SizedBox(
                        width: layout.size.width,
                        height: layout.size.height,
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
                            for (final entry in layout.rects.entries)
                              if (entry.value.overlaps(visible))
                                Positioned.fromRect(
                                  key: ValueKey(entry.key),
                                  rect: entry.value,
                                  child: _node(
                                    context,
                                    layout.nodes[entry.key]!,
                                  ),
                                ),
                          ],
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
              Text(
                node.title,
                maxLines: node.summary ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: node.summary ? 11 : 12,
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
            controller.select(node.id);
            onSelect?.call(node);
          },
          onDoubleTap: () => onActivate?.call(node),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: LongPressDraggable<String>(
                  data: node.id,
                  maxSimultaneousDrags: onMove == null || root || node.summary
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
    for (final edge in layout.edges) {
      final from = layout.rects[edge.from]!, to = layout.rects[edge.to]!;
      if (!Rect.fromPoints(
        Offset(from.right, from.center.dy),
        Offset(to.left, to.center.dy),
      ).inflate(2).overlaps(visible)) {
        continue;
      }
      final x = (from.right + to.left) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(from.right, from.center.dy)
          ..cubicTo(x, from.center.dy, x, to.center.dy, to.left, to.center.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgesPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.color != color ||
      oldDelegate.visible != visible;
}
