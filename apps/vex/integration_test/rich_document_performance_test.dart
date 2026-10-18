import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('large rich document typing and shared selection', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    final vm = fakeWorkspace();
    await vm.initialize(watchFiles: false);
    final source = StringBuffer();
    for (var i = 0; i < 600; i++) {
      source.writeln('## Chapter $i\n');
      for (var paragraph = 0; paragraph < 3; paragraph++) {
        source.writeln(
          'Paragraph $i.$paragraph: **Ideas** meet _structure_ and '
          '`code($i)` with [references](https://example.com/$i). '
          '写下想法，看见脉络。 Keep every source position intact.\n',
        );
      }
      if (i % 10 == 0) {
        source.writeln(
          '| Name | State |\n| --- | --- |\n| **Vex** | Ready |\n',
        );
        source.writeln('```dart\nfinal chapter = $i;\n```\n');
      }
    }
    final original = source.toString();
    vm.editor.session.replace(original);
    vm.editor.session.markSaved();
    vm.setLayout(WorkspaceLayout.instant);
    final results = <Map<String, Object?>>[];
    Future<void> measure(String name, Future<void> Function() run) async {
      final clock = Stopwatch()..start();
      await run();
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      clock.stop();
      expect(tester.takeException(), isNull, reason: name);
      results.add({
        'name': name,
        'wallMs': clock.elapsedMicroseconds / 1000,
        'rssMiB': ProcessInfo.currentRss / 1048576,
      });
    }

    await measure('open', () async {
      await tester.pumpWidget(VexApp(viewModel: vm, windowIntegration: true));
    });
    final paragraph = find
        .textContaining('Paragraph 0.0', findRichText: true)
        .first;
    await measure('begin', () => tester.tap(paragraph));
    final field = find.byKey(const ValueKey('instant-active-input'));
    final input = tester.widget<TextField>(field).controller!;
    final body = input.text;
    for (var i = 0; i < 12; i++) {
      await measure('type:$i', () async {
        input.value = TextEditingValue(
          text: '$body $i',
          selection: TextSelection.collapsed(
            offset: body.length + '$i'.length + 1,
          ),
        );
      });
      await measure('undo:$i', () async => vm.editor.session.undo());
      expect(vm.editor.text, original);
      await tester.tap(paragraph);
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 6; i++) {
      await measure('select-all:$i', () async {
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.controlLeft,
          physicalKey: PhysicalKeyboardKey.controlLeft,
        );
        await tester.sendKeyEvent(
          LogicalKeyboardKey.keyA,
          physicalKey: PhysicalKeyboardKey.keyA,
        );
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.controlLeft,
          physicalKey: PhysicalKeyboardKey.controlLeft,
        );
      });
      expect(vm.editor.selection.textInside(vm.editor.text), original);
      await measure(
        'collapse:$i',
        () => tester.sendKeyEvent(
          LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
        ),
      );
    }
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.controlLeft,
      physicalKey: PhysicalKeyboardKey.controlLeft,
    );
    await tester.sendKeyEvent(
      LogicalKeyboardKey.keyA,
      physicalKey: PhysicalKeyboardKey.keyA,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.controlLeft,
      physicalKey: PhysicalKeyboardKey.controlLeft,
    );
    await tester.pumpAndSettle();
    final buffer = find.byKey(
      const ValueKey('instant-document-selection-input'),
    );
    await measure('replace-all', () async {
      tester
          .widget<TextField>(buffer)
          .controller!
          .value = const TextEditingValue(
        text: '替换全文',
        selection: TextSelection.collapsed(offset: 4),
      );
    });
    expect(vm.editor.text, '替换全文');
    vm.editor.session.undo();
    await tester.pumpAndSettle();
    expect(vm.editor.text, original);
    expect(vm.editor.session.isDirty, isFalse);
    final report = {
      'mode': const bool.fromEnvironment('dart.vm.profile')
          ? 'profile'
          : 'debug',
      'characters': original.length,
      'blocks': vm.editor.document.blocks.length,
      'operations': results,
    };
    debugPrint(jsonEncode(report));
    final output = Platform.environment['VEX_RICH_PERFORMANCE_OUTPUT'];
    if (output != null) {
      await File(output).parent.create(recursive: true);
      await File(output)
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
