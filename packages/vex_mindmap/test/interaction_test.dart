import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

const root = MindMapNode(
  id: 'root',
  title: 'Root',
  children: [
    MindMapNode(id: 'a', title: 'First'),
    MindMapNode(id: 'b', title: 'Second'),
  ],
);

void main() {
  testWidgets('wheel pans; control wheel zoom is bounded and gentle', (
    tester,
  ) async {
    final controller = MindMapController(root);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MindMapView(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    final initial = controller.scale;
    final y = controller.transformation.value.storage[13];
    Future<void> wheel(double delta) async {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: const Offset(400, 300),
          scrollDelta: Offset(0, delta),
        ),
      );
      await tester.pump();
    }

    await wheel(120);
    expect(controller.scale, closeTo(initial, .0001));
    expect(controller.transformation.value.storage[13], closeTo(y - 120, .01));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await wheel(-1200);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(controller.scale / initial, inExclusiveRange(1, 1.12));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Enter, Tab, F2 and arrows perform node operations', (
    tester,
  ) async {
    final controller = MindMapController(root);
    final commands = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindMapView(
            controller: controller,
            onCommand: (node, command) => commands.add('${node.id}:$command'),
            onRename: (_, title) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Root'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(commands, ['root:child']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(controller.selectedId, 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(controller.selectedId, 'b');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(controller.selectedId, 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(commands, ['root:child', 'a:sibling', 'a:child']);
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mindmap-inline-title')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(commands.last, 'a:delete');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
