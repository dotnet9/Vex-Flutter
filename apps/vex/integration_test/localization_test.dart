import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/l10n/l10n.dart';
import 'package:vex/ui/workspace/insert_table_dialog.dart';
import 'package:vex/ui/workspace/workspace_dialogs.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'four languages switch in a native window without changing the document',
    (tester) async {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.ensureInitialized();
        await windowManager.setSize(const Size(1280, 800));
      }
      final vm = fakeWorkspace();
      const original =
          '# 中文 / 繁體 / English / 日本語\n\n同一份 Markdown。\n\n```dart\nprint("Vex");\n```';
      vm.editor.session.replace(original);
      vm.editor.select(2, 4);
      final selection = vm.editor.selection;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: VexApp(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> capture(String name) async {
        final directory =
            Platform.environment['VEX_CAPTURE_DIR'] ??
            (const bool.fromEnvironment('VEX_CAPTURE')
                ? '${Directory.systemTemp.path}/vex-l10n'
                : null);
        if (directory == null) return;
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File('$directory/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      }

      for (final language in ['en', 'zh_Hant', 'ja', 'zh']) {
        final context = tester.element(find.byType(Scaffold).first);
        final shown = showSettings(context, vm);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('language-setting')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(languageNames[language]!).last);
        await tester.pumpAndSettle();
        expect(vm.language, language);
        expect(find.text(vm.strings.settings), findsOneWidget);
        expect(vm.editor.selection, selection);
        await capture('native-settings-$language');
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        await shown;
        vm.setLayout(WorkspaceLayout.read);
        await tester.pumpAndSettle();
        await capture('native-reading-$language');
        await tester.tap(find.byTooltip(vm.strings.markdownTypography));
        await tester.pumpAndSettle();
        await capture('native-typography-$language');
        await tester.tap(find.byTooltip(vm.strings.closePicker));
        await tester.pumpAndSettle();
        final table = showInsertTableDialog(context);
        await tester.pumpAndSettle();
        await capture('native-table-$language');
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        await table;
        vm.setLayout(WorkspaceLayout.map);
        await tester.pumpAndSettle();
        expect(find.byTooltip(vm.strings.fitCanvas), findsOneWidget);
        expect(vm.editor.text, original);
        expect(vm.editor.session.canUndo, isTrue);
        expect(tester.takeException(), isNull);
      }
      vm.editor.session.undo();
      expect(vm.editor.text, vm.strings.sampleDesign);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
