import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

void main() {
  const root = MindMapNode(
    id: 'root',
    title: 'Root',
    children: [
      MindMapNode(
        id: 'a',
        title: 'A',
        children: [MindMapNode(id: 'a1', title: 'A1')],
      ),
      MindMapNode(
        id: 'b',
        title: 'B',
        children: [MindMapNode(id: 'b1', title: 'B1')],
      ),
    ],
  );
  test('branch identities survive every layout and collapse', () {
    for (final mode in MindMapLayoutMode.values) {
      final layout = MindMapLayout.compute(root, mode: mode);
      expect(layout.branchIndices, {'a': 0, 'a1': 0, 'b': 1, 'b1': 1});
      expect(layout.branchIndices, same(layout.branchIndices));
      expect(
        MindMapLayout.compute(root, mode: mode, collapsed: {'a'}).branchIndices,
        {'a': 0, 'b': 1, 'b1': 1},
      );
      expect(
        MindMapLayout.compute(
          root,
          mode: mode,
          collapsed: {'root'},
        ).branchIndices,
        isEmpty,
      );
    }
  });
  for (final brightness in Brightness.values) {
    final colors = ColorScheme.fromSeed(
      seedColor: Colors.red,
      brightness: brightness,
    );
    test('colorful connectors share their branch colors in $brightness', () {
      final edges = <Color>{};
      for (var i = 0; i < 4; i++) {
        final node = MindMapNodeStyle.resolve(
          MindMapStyle.colorful,
          colors,
          root: false,
          branch: i,
        );
        final edge = MindMapEdgeStyle.resolve(
          MindMapStyle.colorful,
          colors,
          branch: i,
        );
        expect(edge.color.withValues(alpha: 1), node.border);
        expect(edge.width, 2);
        edges.add(edge.color);
      }
      expect(edges, hasLength(4));
      final mono = MindMapEdgeStyle.resolve(MindMapStyle.mono, colors);
      expect(mono.color.withValues(alpha: 1), colors.onSurface);
      expect(mono.width, 1);
      expect(
        MindMapNodeStyle.resolve(MindMapStyle.mono, colors, root: false).border,
        colors.onSurface,
      );
      final rootStyle = MindMapNodeStyle.resolve(
        MindMapStyle.underline,
        colors,
        root: true,
      );
      expect(rootStyle.underline, isFalse);
      expect(rootStyle.fill, colors.primary);
      expect(
        MindMapNodeStyle.resolve(
          MindMapStyle.underline,
          colors,
          root: false,
        ).underline,
        isTrue,
      );
      expect(
        MindMapNodeStyle.resolve(
          MindMapStyle.capsule,
          colors,
          root: false,
        ).border,
        Colors.transparent,
      );
      expect(
        MindMapNodeStyle.resolve(
          MindMapStyle.outline,
          colors,
          root: true,
        ).foreground,
        colors.primary,
      );
    });
  }
}
