import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/ui/workspace/workspace_sidebar.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('large outlines build only viewport rows and keep navigation', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    vm.editor.session.replace(
      List.generate(3000, (i) => '## Heading $i\n\nBody\n\n').join(),
    );
    vm.setOutline(true);
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    final sidebar = find.byType(WorkspaceSidebar);
    final rows = find.descendant(
      of: sidebar,
      matching: find.byType(TextButton),
    );
    expect(rows.evaluate().length, lessThan(40));
    expect(find.text('Heading 2999'), findsNothing);
    final list = find.descendant(of: sidebar, matching: find.byType(ListView));
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(rows.evaluate().length, lessThan(50));
    final visible = find
        .descendant(of: sidebar, matching: find.textContaining('Heading'))
        .hitTestable()
        .first;
    final title = tester.widget<Text>(visible).data!;
    await tester.tap(visible);
    await tester.pumpAndSettle();
    expect(vm.selectedHeading!.title, title);
    expect(vm.editor.session.canUndo, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
