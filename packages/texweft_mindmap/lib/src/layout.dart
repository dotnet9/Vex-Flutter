import 'dart:math' as math;

import 'package:flutter/widgets.dart';

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
  MindMapLayout._(this.rects, this.nodes, this.edges, this.size);
  factory MindMapLayout.compute(
    MindMapNode root, {
    Set<String> collapsed = const {},
    double nodeWidth = 176,
    double nodeHeight = 66,
    double horizontalGap = 58,
    double verticalGap = 18,
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

    final totalHeight = measure(root);
    var right = 0.0;
    void place(MindMapNode node, int depth, double top) {
      final height = heights[node.id]!;
      final rect = Rect.fromLTWH(
        32 + depth * (nodeWidth + horizontalGap),
        32 + top + (height - nodeHeight) / 2,
        nodeWidth,
        nodeHeight,
      );
      rects[node.id] = rect;
      right = math.max(right, rect.right);
      if (collapsed.contains(node.id)) return;
      var childTop = top;
      for (final child in node.children) {
        edges.add((from: node.id, to: child.id));
        place(child, depth + 1, childTop);
        childTop += heights[child.id]! + verticalGap;
      }
    }

    place(root, 0, 0);
    return MindMapLayout._(
      Map.unmodifiable(rects),
      Map.unmodifiable(nodes),
      List.unmodifiable(edges),
      Size(right + 32, totalHeight + 64),
    );
  }
  final Map<String, Rect> rects;
  final Map<String, MindMapNode> nodes;
  final List<({String from, String to})> edges;
  final Size size;
}
