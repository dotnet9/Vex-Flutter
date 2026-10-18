import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

void main() {
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
