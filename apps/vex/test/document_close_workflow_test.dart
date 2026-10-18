import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/core/app_widgets.dart';

import 'support/fakes.dart';

void main() {
  for (final switchDocument in [false, true]) {
    testWidgets(
      'save then close preserves ${switchDocument ? 'the newly selected document' : 'typing during save'}',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final vm = fakeWorkspace();
        final files = vm.files as MemoryFiles;
        files.content['/a.md'] = 'on disk';
        await vm.openPath('/a.md');
        final document = vm.current;
        vm.editor.session.replace('save this snapshot');
        vm.setLayout(WorkspaceLayout.source);
        final entered = Completer<void>(), release = Completer<void>();
        files.beforeWrite = () async {
          entered.complete();
          await release.future;
        };
        await tester.pumpWidget(VexApp(viewModel: vm));
        await tester.pumpAndSettle();
        await tester.tap(find.text(vm.strings.menuFile));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('menu-close-document')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog),
            matching: find.text(vm.strings.save),
          ),
        );
        await tester.pumpAndSettle();
        expect(entered.isCompleted, isTrue);

        if (switchDocument) vm.newDocument();
        final writingDocument = vm.current;
        vm.editor.session.replace('keep this new input');
        release.complete();
        await tester.pumpAndSettle();

        expect(files.content['/a.md'], 'save this snapshot');
        expect(vm.current, same(writingDocument));
        expect(vm.editor.session.text, 'keep this new input');
        expect(vm.editor.session.isDirty, isTrue);
        expect(vm.documents.contains(document), !switchDocument);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  test(
    'close checks the revision from before waiting for a pending save',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content['/a.md'] = 'on disk';
      await vm.openPath('/a.md');
      vm.editor.session.replace('save this snapshot');
      final document = vm.current;
      final entered = Completer<void>(), release = Completer<void>();
      files.beforeWrite = () async {
        entered.complete();
        await release.future;
      };

      final saving = vm.save();
      await entered.future;
      final closing = vm.closeCurrent();
      vm.editor.session.replace('typed while waiting');
      release.complete();
      await saving;
      await closing;

      expect(vm.current, same(document));
      expect(vm.documents, contains(document));
      expect(vm.editor.session.text, 'typed while waiting');
      expect(vm.editor.session.isDirty, isTrue);
      expect(
        (vm.recovery as MemoryRecovery).value.single['text'],
        'typed while waiting',
      );
    },
  );
}
