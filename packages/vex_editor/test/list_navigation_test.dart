import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex_editor/src/list_navigation.dart';

void main() {
  testWidgets(
    'distant jumps skip intermediate viewports and remain cancellable',
    (tester) async {
      final list = ListController(), scroll = ScrollController();
      final navigator = MarkdownListNavigator(
        vsync: const TestVSync(),
        list: list,
        scroll: scroll,
      );
      final built = <int>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuperListView.builder(
              listController: list,
              controller: scroll,
              itemCount: 10000,
              itemBuilder: (context, index) {
                built.add(index);
                return SizedBox(
                  height: 80 + index % 3 * 20,
                  child: Text('Row $index'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final index in [9000, 20, 7000]) {
        built.clear();
        navigator.reveal(index);
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.text('Row $index'), findsOneWidget);
        expect(
          tester
              .getRect(find.byType(Scaffold))
              .contains(tester.getCenter(find.text('Row $index'))),
          isTrue,
        );
        expect(
          built.length,
          lessThan(80),
          reason: 'Do not render skipped chapters.',
        );
      }
      navigator.reveal(0);
      await tester.pump(const Duration(milliseconds: 30));
      navigator.cancel();
      final stopped = scroll.offset;
      await tester.pump(const Duration(milliseconds: 300));
      expect(scroll.offset, stopped);
      await tester.pumpWidget(const SizedBox());
      navigator.dispose();
      list.dispose();
      scroll.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
