import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_mindmap/texweft_mindmap.dart';

void main() {
  const root = MindMapNode(
    id: 'root',
    title: '根',
    children: [
      MindMapNode(
        id: 'a',
        title: '甲',
        children: [MindMapNode(id: 'a1', title: '子')],
      ),
      MindMapNode(id: 'b', title: '乙'),
    ],
  );
  test('subtrees do not overlap and all nodes stay within canvas bounds', () {
    final layout = MindMapLayout.compute(root);
    expect(layout.nodes.length, 4);
    expect(layout.edges.length, 3);
    expect(layout.rects['a']!.bottom, lessThan(layout.rects['b']!.top));
    for (final rect in layout.rects.values) {
      expect(rect.right, lessThanOrEqualTo(layout.size.width));
      expect(rect.bottom, lessThanOrEqualTo(layout.size.height));
    }
  });
  test('collapsed children leave no edges or reserved space', () {
    final full = MindMapLayout.compute(root);
    final collapsed = MindMapLayout.compute(root, collapsed: {'root'});
    expect(collapsed.rects.keys, ['root']);
    expect(collapsed.edges, isEmpty);
    expect(collapsed.size.height, lessThan(full.size.height));
  });
  test('duplicate IDs are rejected before publishing an invalid layout', () {
    expect(
      () => MindMapLayout.compute(
        const MindMapNode(
          id: 'a',
          title: '一',
          children: [MindMapNode(id: 'a', title: '二')],
        ),
      ),
      throwsArgumentError,
    );
  });
}
