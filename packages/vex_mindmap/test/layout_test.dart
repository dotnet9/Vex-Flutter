import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

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
  for (final mode in MindMapLayoutMode.values) {
    test('${mode.name} preserves order, avoids overlap and stays in bounds', () {
      final tree = MindMapNode(
        id: 'root',
        title: 'Root',
        children: [
          for (var i = 0; i < 9; i++)
            MindMapNode(
              id: 'b$i',
              title: 'Branch',
              children: [
                for (var j = 0; j < i % 4; j++)
                  MindMapNode(
                    id: 'b$i-$j',
                    title: 'Child',
                    children: [MindMapNode(id: 'b$i-$j-leaf', title: 'Leaf')],
                  ),
              ],
            ),
        ],
      );
      final layout = MindMapLayout.compute(tree, mode: mode);
      expect(layout.mode, mode);
      expect(layout.nodes.keys, MindMapLayout.compute(tree).nodes.keys);
      final rects = layout.rects.values.toList();
      for (var i = 0; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(0));
        expect(rects[i].top, greaterThanOrEqualTo(0));
        expect(rects[i].right, lessThanOrEqualTo(layout.size.width));
        expect(rects[i].bottom, lessThanOrEqualTo(layout.size.height));
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason:
                '${layout.rects.keys.elementAt(i)} / ${layout.rects.keys.elementAt(j)}',
          );
        }
      }
      final controller = MindMapController(tree)..setMode(mode);
      controller.toggle('b2');
      expect(controller.layout.nodes.containsKey('b2-0'), isFalse);
      expect(controller.layout.mode, mode);
      controller.focusNode('b2-0', const Size(800, 600));
      expect(controller.layout.mode, mode);
      expect(controller.selectedId, 'b2-0');
      controller.setRoot(tree);
      expect(controller.layout.mode, mode);
      controller.toggleAll();
      expect(controller.layout.mode, mode);
      controller.dispose();
    });
  }
  test('focus reveals collapsed ancestors and centers the requested node', () {
    final controller = MindMapController(root);
    controller.toggle('root');
    controller.toggle('a');
    controller.focusNode('a1', const Size(1000, 700));
    expect(controller.selectedId, 'a1');
    expect(controller.collapsed, isEmpty);
    final target = controller.layout.rects['a1']!.center;
    final transform = controller.transformation.value;
    expect(
      target.dx * controller.scale + transform.getTranslation().x,
      closeTo(500, .001),
    );
    expect(
      target.dy * controller.scale + transform.getTranslation().y,
      closeTo(350, .001),
    );
    expect(controller.root, same(root));
    final before = transform.clone();
    controller.focusNode('missing', const Size(1000, 700));
    expect(controller.transformation.value, before);
    controller.dispose();
  });
  test('collapsed children leave no edges or reserved space', () {
    final full = MindMapLayout.compute(root);
    final collapsed = MindMapLayout.compute(root, collapsed: {'root'});
    expect(collapsed.rects.keys, ['root']);
    expect(collapsed.edges, isEmpty);
    expect(collapsed.size.height, lessThan(full.size.height));
  });
  test(
    'large maps fit completely and can return to a readable offscreen node',
    () {
      final controller = MindMapController(
        MindMapNode(
          id: 'large',
          title: 'large',
          children: [
            for (var i = 0; i < 1500; i++)
              MindMapNode(id: '$i', title: 'Section $i'),
          ],
        ),
      );
      const viewport = Size(1000, 700);
      controller.fit(viewport);
      expect(controller.scale, lessThan(.15));
      for (final rect in controller.layout.rects.values) {
        final visible = MatrixUtils.transformRect(
          controller.transformation.value,
          rect,
        );
        expect(visible.left, greaterThanOrEqualTo(0));
        expect(visible.top, greaterThanOrEqualTo(0));
        expect(visible.right, lessThanOrEqualTo(viewport.width));
        expect(visible.bottom, lessThanOrEqualTo(viewport.height));
      }
      controller.zoom(1 / 1.15, viewport);
      expect(
        controller.scale,
        greaterThanOrEqualTo(controller.minimumScaleFor(viewport)),
      );
      controller.focusNode('1499', viewport);
      expect(controller.scale, 1);
      expect(controller.selectedId, '1499');
      controller.dispose();
    },
  );
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
