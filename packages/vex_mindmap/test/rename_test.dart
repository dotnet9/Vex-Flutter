import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

void main() {
  testWidgets('double click renames inside the node and Escape cancels', (
    tester,
  ) async {
    final controller = MindMapController(
      const MindMapNode(id: 'root', title: 'Original'),
    );
    final titles = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindMapView(
            controller: controller,
            onRename: (_, title) {
              titles.add(title);
              controller.setRoot(MindMapNode(id: 'root', title: title));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original'));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('mindmap-inline-title'));
    expect(input, findsOneWidget);
    await tester.enterText(input, 'New title');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(titles, ['New title']);
    expect(find.text('New title'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    await tester.enterText(input, 'Cancelled');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(titles, ['New title']);
    expect(find.text('New title'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
