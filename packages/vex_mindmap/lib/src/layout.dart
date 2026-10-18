import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum MindMapLayoutMode { right, balanced, radial, down, outline, fishbone }

final class MindMapNode {
  const MindMapNode({
    required this.id,
    required this.title,
    this.subtitle,
    this.summary = false,
    this.children = const [],
  });
  final String id, title;
  final String? subtitle;
  final bool summary;
  final List<MindMapNode> children;
}

/// Deterministic subtree layout; collapsed branches consume only one row.
final class MindMapLayout {
  MindMapLayout._(
    this.rects,
    this.nodes,
    this.edges,
    this.size,
    this.mode,
    this.paths,
  );
  factory MindMapLayout.compute(
    MindMapNode root, {
    Set<String> collapsed = const {},
    double nodeWidth = 176,
    double nodeHeight = 66,
    double horizontalGap = 58,
    double verticalGap = 18,
    MindMapLayoutMode mode = MindMapLayoutMode.right,
  }) {
    final rects = <String, Rect>{};
    final nodes = <String, MindMapNode>{};
    final heights = <String, double>{};
    final edges = <({String from, String to})>[];
    double measure(MindMapNode node) {
      if (nodes.containsKey(node.id)) {
        throw ArgumentError('节点 ID 必须唯一，且不能存在循环：${node.id}');
      }
      nodes[node.id] = node;
      final children = collapsed.contains(node.id)
          ? <MindMapNode>[]
          : node.children;
      final contentHeight =
          children.fold<double>(0, (total, child) => total + measure(child)) +
          math.max(0, children.length - 1) * verticalGap;
      return heights[node.id] = math.max(nodeHeight, contentHeight);
    }

    measure(root);
    void place(MindMapNode node, int depth, double top) {
      final height = heights[node.id]!;
      final rect = Rect.fromLTWH(
        32 + depth * (nodeWidth + horizontalGap),
        32 + top + (height - nodeHeight) / 2,
        nodeWidth,
        nodeHeight,
      );
      rects[node.id] = rect;
      if (collapsed.contains(node.id)) return;
      var childTop = top;
      for (final child in node.children) {
        edges.add((from: node.id, to: child.id));
        place(child, depth + 1, childTop);
        childTop += heights[child.id]! + verticalGap;
      }
    }

    place(root, 0, 0);
    final centers = {for (final e in rects.entries) e.key: e.value.center};
    final children = <String, List<MindMapNode>>{
      for (final node in nodes.values)
        node.id: collapsed.contains(node.id) ? [] : node.children,
    };
    void horizontal(MindMapNode node, double x, double y, double sign) {
      centers[node.id] = Offset(x, y);
      final group = children[node.id]!;
      final height =
          group.fold<double>(0, (sum, n) => sum + heights[n.id]!) +
          math.max(0, group.length - 1) * verticalGap;
      var top = y - height / 2;
      for (final child in group) {
        horizontal(
          child,
          x + sign * (nodeWidth + horizontalGap),
          top + heights[child.id]! / 2,
          sign,
        );
        top += heights[child.id]! + verticalGap;
      }
    }

    final widths = <String, double>{};
    double measureWidth(MindMapNode node) => widths[node.id] = math.max(
      nodeWidth,
      children[node.id]!.fold<double>(
            0,
            (sum, child) => sum + measureWidth(child),
          ) +
          math.max(0, children[node.id]!.length - 1) * verticalGap,
    );
    void vertical(MindMapNode node, double x, double y, double sign) {
      centers[node.id] = Offset(x, y);
      final group = children[node.id]!;
      final width =
          group.fold<double>(0, (sum, n) => sum + widths[n.id]!) +
          math.max(0, group.length - 1) * verticalGap;
      var left = x - width / 2;
      for (final child in group) {
        vertical(
          child,
          left + widths[child.id]! / 2,
          y + sign * (nodeHeight + 80),
          sign,
        );
        left += widths[child.id]! + verticalGap;
      }
    }

    switch (mode) {
      case MindMapLayoutMode.right:
        break;
      case MindMapLayoutMode.balanced:
        final groups = [<MindMapNode>[], <MindMapNode>[]];
        final loads = [0.0, 0.0];
        for (final child in children[root.id]!) {
          final side = loads[0] <= loads[1] ? 0 : 1;
          groups[side].add(child);
          loads[side] += heights[child.id]! + verticalGap;
        }
        centers[root.id] = Offset.zero;
        for (var side = 0; side < 2; side++) {
          var top = -(loads[side] - verticalGap) / 2;
          for (final child in groups[side]) {
            horizontal(
              child,
              (side == 0 ? 1 : -1) * (nodeWidth + horizontalGap),
              top + heights[child.id]! / 2,
              side == 0 ? 1 : -1,
            );
            top += heights[child.id]! + verticalGap;
          }
        }
      case MindMapLayoutMode.down:
        measureWidth(root);
        vertical(root, 0, 0, 1);
      case MindMapLayoutMode.outline:
        var row = 0;
        void visit(MindMapNode node, int depth) {
          centers[node.id] = Offset(
            depth * 64,
            row++ * (nodeHeight + verticalGap),
          );
          for (final child in children[node.id]!) {
            visit(child, depth + 1);
          }
        }
        visit(root, 0);
      case MindMapLayoutMode.fishbone:
        measureWidth(root);
        var cursor = 0.0;
        var index = 0;
        for (final child in children[root.id]!) {
          final width = widths[child.id]!;
          final sign = (index++).isEven ? -1.0 : 1.0;
          vertical(child, cursor + width / 2, sign * (nodeHeight + 100), sign);
          cursor += width + 100;
        }
        centers[root.id] = Offset(cursor + nodeWidth / 2 + 40, 0);
      case MindMapLayoutMode.radial:
        final weights = <String, int>{};
        int weigh(MindMapNode node) => weights[node.id] = math.max(
          1,
          children[node.id]!.fold<int>(0, (sum, child) => sum + weigh(child)),
        );
        weigh(root);
        final rings = <int, List<double>>{};
        final polar = <String, ({int depth, double angle})>{};
        void distribute(
          MindMapNode node,
          int depth,
          double start,
          double span,
        ) {
          final angle = start + span / 2;
          polar[node.id] = (depth: depth, angle: angle);
          if (depth > 0) (rings[depth] ??= []).add(angle);
          var cursor = start;
          for (final child in children[node.id]!) {
            final portion = span * weights[child.id]! / weights[node.id]!;
            distribute(child, depth + 1, cursor, portion);
            cursor += portion;
          }
        }
        distribute(root, 0, -math.pi / 2, 2 * math.pi);
        // Ring separation bounds each card by its diagonal, avoiding quadratic
        // pair comparisons even for several thousand visible nodes.
        final diameter =
            math.sqrt(nodeWidth * nodeWidth + nodeHeight * nodeHeight) +
            verticalGap;
        var step = math.max(nodeWidth + horizontalGap, diameter);
        for (final ring in rings.entries) {
          final angles = ring.value..sort();
          if (angles.length < 2) continue;
          var gap = 2 * math.pi - angles.last + angles.first;
          for (var i = 1; i < angles.length; i++) {
            gap = math.min(gap, angles[i] - angles[i - 1]);
          }
          step = math.max(step, diameter / (2 * math.sin(gap / 2) * ring.key));
        }
        for (final entry in polar.entries) {
          centers[entry.key] =
              Offset(math.cos(entry.value.angle), math.sin(entry.value.angle)) *
              (entry.value.depth * step);
        }
    }
    final minX =
        centers.values.map((p) => p.dx).reduce(math.min) - nodeWidth / 2;
    final minY =
        centers.values.map((p) => p.dy).reduce(math.min) - nodeHeight / 2;
    for (final entry in centers.entries) {
      rects[entry.key] = Rect.fromCenter(
        center: entry.value + Offset(32 - minX, 32 - minY),
        width: nodeWidth,
        height: nodeHeight,
      );
    }
    final paths = <Path>[];
    for (final edge in edges) {
      final a = rects[edge.from]!, b = rects[edge.to]!;
      final path = Path();
      if (mode == MindMapLayoutMode.radial) {
        Offset ray(Rect rect, Offset vector) {
          final ratio = math.min(
            rect.width / 2 / vector.dx.abs(),
            rect.height / 2 / vector.dy.abs(),
          );
          return rect.center + vector * ratio;
        }

        final vector = b.center - a.center;
        final start = ray(a, vector), end = ray(b, -vector);
        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);
      } else if (mode == MindMapLayoutMode.fishbone && edge.from == root.id) {
        path.moveTo(b.center.dx + 64, a.center.dy);
        path.lineTo(b.center.dx, b.center.dy < a.center.dy ? b.bottom : b.top);
      } else if (mode == MindMapLayoutMode.down ||
          mode == MindMapLayoutMode.fishbone) {
        final sign = b.center.dy < a.center.dy ? -1 : 1;
        final y1 = a.center.dy + sign * nodeHeight / 2,
            y2 = b.center.dy - sign * nodeHeight / 2;
        path.moveTo(a.center.dx, y1);
        path.cubicTo(
          a.center.dx,
          (y1 + y2) / 2,
          b.center.dx,
          (y1 + y2) / 2,
          b.center.dx,
          y2,
        );
      } else if (mode == MindMapLayoutMode.outline) {
        path.moveTo(a.left + 16, a.bottom);
        path.lineTo(a.left + 16, b.center.dy);
        path.lineTo(b.left, b.center.dy);
      } else {
        final sign = b.center.dx < a.center.dx ? -1 : 1;
        final x1 = a.center.dx + sign * nodeWidth / 2,
            x2 = b.center.dx - sign * nodeWidth / 2;
        path.moveTo(x1, a.center.dy);
        path.cubicTo(
          (x1 + x2) / 2,
          a.center.dy,
          (x1 + x2) / 2,
          b.center.dy,
          x2,
          b.center.dy,
        );
      }
      paths.add(path);
    }
    if (mode == MindMapLayoutMode.fishbone && children[root.id]!.isNotEmpty) {
      paths.add(
        Path()
          ..moveTo(
            rects[children[root.id]!.first.id]!.center.dx + 64,
            rects[root.id]!.center.dy,
          )
          ..lineTo(rects[root.id]!.left, rects[root.id]!.center.dy),
      );
    }
    return MindMapLayout._(
      Map.unmodifiable(rects),
      Map.unmodifiable(nodes),
      List.unmodifiable(edges),
      Size(
        rects.values.map((r) => r.right).reduce(math.max) + 32,
        rects.values.map((r) => r.bottom).reduce(math.max) + 32,
      ),
      mode,
      List.unmodifiable(paths),
    );
  }
  final Map<String, Rect> rects;
  final Map<String, MindMapNode> nodes;
  final List<({String from, String to})> edges;
  final Size size;
  final MindMapLayoutMode mode;
  final List<Path> paths;

  /// Stable first-level branch identity for both nodes and their connectors.
  late final Map<String, int> branchIndices = _indexBranches();
  Map<String, int> _indexBranches() {
    final result = <String, int>{};
    final root = edges.firstOrNull?.from;
    var branch = 0;
    for (final edge in edges) {
      result[edge.to] = edge.from == root ? branch++ : result[edge.from]!;
    }
    return Map.unmodifiable(result);
  }
}
