import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/ui/workspace/workspace_menu.dart';
import 'package:vex/ui/workspace/workspace_menu_widgets.dart';

import 'support/fakes.dart';

void main() {
  for (final size in [const Size(1280, 800), const Size(900, 600)]) {
    for (final scale in [1.0, 1.25, 1.5, 2.0]) {
      testWidgets(
        'flat menus fit $size at text scale $scale without scrolling',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final vm = fakeWorkspace();
          addTearDown(vm.dispose);
          final menus = workspaceMenus(
            vm,
            macOS: false,
            desktop: true,
            maxPanes: 3,
          );
          for (final menu in menus) {
            final controller = MenuController();
            String? selected;
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => MenuAnchor(
                      controller: controller,
                      menuChildren: workspaceMenuWidgets(
                        context,
                        menu.children,
                        (id) => selected = id,
                      ),
                      builder: (context, controller, child) => TextButton(
                        onPressed: controller.open,
                        child: Text(menu.label),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text(menu.label));
            await tester.pumpAndSettle();
            final entries = menu.children.where(
              (item) => !item.isSeparator && !item.toolbar,
            );
            for (final entry in entries) {
              final bounds = tester.getRect(
                find.byKey(ValueKey('menu-${entry.id}')),
              );
              expect(bounds.top, greaterThanOrEqualTo(0), reason: entry.id);
              expect(
                bounds.bottom,
                lessThanOrEqualTo(size.height),
                reason: entry.id,
              );
              expect(
                bounds.right,
                lessThanOrEqualTo(size.width),
                reason: entry.id,
              );
              expect(bounds.left, greaterThanOrEqualTo(0), reason: entry.id);
            }
            for (final scroll in tester.stateList<ScrollableState>(
              find.byType(Scrollable),
            )) {
              expect(scroll.position.maxScrollExtent, 0, reason: menu.id);
            }
            final first = entries.firstWhere(
              (item) => item.enabled && item.children.isEmpty,
            );
            await tester.tap(find.byKey(ValueKey('menu-${first.id}')));
            await tester.pumpAndSettle();
            expect(selected, first.id);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets('column menu keeps keyboard activation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final menu = workspaceMenus(
      vm,
      macOS: false,
      desktop: true,
      maxPanes: 3,
    ).firstWhere((m) => m.id == 'view');
    final controller = MenuController();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => MenuAnchor(
              controller: controller,
              menuChildren: workspaceMenuWidgets(
                context,
                menu.children,
                (id) => selected = id,
                firstFocusNode: focus,
              ),
              builder: (context, controller, child) => TextButton(
                onPressed: controller.open,
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, menu.children.first.id);
  });
}
