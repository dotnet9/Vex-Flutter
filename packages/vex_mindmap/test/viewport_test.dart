import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

void main() {
  testWidgets('resizing a pane preserves its scene center and user zoom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MindMapController(
      const MindMapNode(
        id: 'root',
        title: 'Root',
        children: [MindMapNode(id: 'chapter', title: 'Chapter')],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MindMapView(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    controller.focusNode('chapter', const Size(1000, 700), scale: 1.6);
    final center = controller.transformation.toScene(const Offset(500, 350));
    await tester.binding.setSurfaceSize(const Size(500, 300));
    await tester.pumpAndSettle();
    final resized = controller.transformation.toScene(const Offset(250, 150));
    expect(resized.dx, closeTo(center.dx, .01));
    expect(resized.dy, closeTo(center.dy, .01));
    expect(controller.scale, 1.6);
    expect(controller.selectedId, 'chapter');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
    'chapter following reveals a collapsed node and preserves manual pan',
    (tester) async {
      final controller = MindMapController(
        const MindMapNode(
          id: 'root',
          title: 'Root',
          children: [
            MindMapNode(
              id: 'branch',
              title: 'Branch',
              children: [MindMapNode(id: 'leaf', title: 'Leaf')],
            ),
            MindMapNode(id: 'other', title: 'Other'),
          ],
        ),
      );
      controller.toggle('branch');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MindMapView(controller: controller, showControls: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scale = controller.scale;
      controller.follow('leaf');
      await tester.pumpAndSettle();
      expect(controller.collapsed, isNot(contains('branch')));
      expect(find.text('Leaf').hitTestable(), findsOneWidget);
      expect(controller.scale, scale);
      controller.transformation.value = controller.transformation.value.clone()
        ..translateByDouble(30, 40, 0, 1);
      final manual = controller.transformation.value.clone();
      controller.follow('leaf');
      await tester.pumpAndSettle();
      expect(controller.transformation.value, manual);
      controller.follow('other');
      await tester.pumpAndSettle();
      expect(controller.transformation.value, isNot(manual));
      expect(find.text('Other').hitTestable(), findsOneWidget);
      expect(controller.scale, scale);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  test(
    'view snapshots restore independent transform, collapse and selection',
    () {
      final controller = MindMapController(
        const MindMapNode(
          id: 'root',
          title: 'Root',
          children: [
            MindMapNode(
              id: 'branch',
              title: 'Branch',
              children: [MindMapNode(id: 'leaf', title: 'Leaf')],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      controller.setMode(MindMapLayoutMode.balanced);
      controller.setStyle(MindMapStyle.capsule);
      controller.toggle('branch');
      controller.select('branch');
      controller.fit(const Size(700, 500));
      controller.zoom(1.5, const Size(700, 500));
      final expected = Matrix4.copy(controller.transformation.value);
      final snapshot = controller.snapshotView();
      controller.toggleAll();
      controller.setMode(MindMapLayoutMode.fishbone);
      controller.setStyle(MindMapStyle.mono);
      controller.select(null);
      controller.fit(const Size(400, 300));
      controller.restoreView(snapshot);
      expect(controller.collapsed, {'branch'});
      expect(controller.selectedId, 'branch');
      expect(controller.mode, MindMapLayoutMode.balanced);
      expect(controller.style, MindMapStyle.capsule);
      expect(controller.fitRequested, isFalse);
      expect(controller.transformation.value, expected);
      controller.transformation.value.translateByDouble(20, 30, 0, 1);
      controller.restoreView(snapshot);
      expect(controller.transformation.value, expected);
    },
  );

  testWidgets(
    'full overview avoids thousands of widgets and still opens a node',
    (tester) async {
      const viewport = Size(1000, 700);
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = MindMapController(
        MindMapNode(
          id: 'root',
          title: 'Root',
          children: [
            for (var i = 0; i < 1500; i++)
              MindMapNode(id: '$i', title: 'Node $i'),
          ],
        ),
      );
      controller.fit(viewport);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MindMapView(
              controller: controller,
              showControls: false,
              onSelect: (node) => controller.focusNode(node.id, viewport),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DragTarget<String>), findsNothing);
      expect(find.byType(LongPressDraggable<String>), findsNothing);
      final target = MatrixUtils.transformPoint(
        controller.transformation.value,
        controller.layout.rects['1499']!.center,
      );
      await tester.tapAt(target);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(controller.selectedId, '1499');
      expect(controller.scale, 1);
      expect(find.text('Node 1499').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'large maps render visible nodes and reveal nodes after panning',
    (tester) async {
      final controller = MindMapController(
        MindMapNode(
          id: 'root',
          title: 'Root',
          children: List.generate(
            2000,
            (i) => MindMapNode(id: '$i', title: 'Node $i'),
          ),
        ),
      );
      controller.fitRequested = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MindMapView(controller: controller, showControls: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DragTarget<String>).evaluate().length, lessThan(40));
      expect(find.text('Node 1500'), findsNothing);
      final target = controller.layout.rects['1500']!;
      controller.transformation.value = Matrix4.translationValues(
        40 - target.left,
        100 - target.top,
        0,
      );
      await tester.pumpAndSettle();
      expect(find.text('Node 1500').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Node 1500'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(controller.selectedId, '1500');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
