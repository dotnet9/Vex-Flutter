import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/l10n/l10n.dart';
import 'package:texweft/ui/workspace/builtin_documents.dart';
import 'package:texweft/ui/workspace/workspace_dialogs.dart';

import 'support/fakes.dart';

void main() {
  test('only known bundled document flags select a document', () {
    expect(
      BuiltinDocument.fromArguments(['--builtin-document=thanks']),
      BuiltinDocument.thanks,
    );
    expect(
      BuiltinDocument.fromArguments(['--builtin-document=../../notes']),
      isNull,
    );
    expect(BuiltinDocument.fromArguments(['C:/notes.md']), isNull);
  });
  testWidgets(
    'desktop opens bundled Markdown in a separate read-only process',
    (tester) async {
      String? executable;
      List<String>? arguments;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBuiltinDocument(
                context,
                BuiltinDocument.changelog,
                startProcess: (exe, args) async {
                  executable = exe;
                  arguments = args;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(executable, isNotEmpty);
      expect(arguments, contains('--builtin-document=changelog'));
      expect(find.byType(Dialog), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final size in [const Size(390, 844), const Size(900, 700)]) {
    for (final document in BuiltinDocument.values) {
      testWidgets(
        '${document.name} has one scroll body and fixed chrome at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final vm = fakeWorkspace();
          await tester.pumpWidget(TexweftApp(viewModel: vm));
          final context = tester.element(find.byType(Scaffold).first);
          await tester.runAsync(() async {
            unawaited(showBuiltinDocument(context, document));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          final dialog = find.byType(Dialog);
          expect(dialog, findsOneWidget);
          final scrolls = find.descendant(
            of: dialog,
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          );
          expect(scrolls, findsOneWidget);
          final header = find.byKey(const ValueKey('dialog-titlebar'));
          final title = tester.getRect(header);
          final footer = find.widgetWithText(TextButton, vm.strings.close);
          final bottom = tester.getRect(footer);
          final scroll = tester.state<ScrollableState>(scrolls);
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.getRect(header), title);
          expect(tester.getRect(footer), bottom);
          expect(
            find.descendant(of: dialog, matching: find.byType(TextField)),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          vm.dispose();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
  testWidgets('about is 420px and keeps update action beside changelog', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    await tester.pumpWidget(TexweftApp(viewModel: vm));
    showAbout(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('dialog-titlebar'))).width,
      420,
    );
    final title = find.descendant(
      of: find.byKey(const ValueKey('dialog-titlebar')),
      matching: find.text(vm.strings.about),
    );
    expect(title, findsOneWidget);
    final log = find.widgetWithText(TextButton, vm.strings.changelog);
    final check = find.byKey(const ValueKey('about-check-updates'));
    expect(tester.getCenter(check).dy, tester.getCenter(log).dy);
    expect(tester.getCenter(check).dx, greaterThan(tester.getCenter(log).dx));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
