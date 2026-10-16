import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native code block renders quietly and edits without exposing fences',
    (tester) async {
      await windowManager.ensureInitialized();
      await windowManager.setSize(const Size(1280, 800));
      final vm = fakeWorkspace();
      await vm.initialize(watchFiles: false);
      const code =
          'S-FlowC.slnx\n├─ 01 Application\n│  ├─ SFlowC\n└─ 99 External Dependencies';
      const source = '# 代码示例\n\n```markdown\n$code\n```\n\n点击这里继续写作。';
      vm.editor.session.replace(source);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: TexweftApp(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> capture(String name) async {
        final directory = Platform.environment['TEXWEFT_CAPTURE_DIR'];
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

      final language = find.byKey(const ValueKey('instant-code-language'));
      final body = find.byKey(const ValueKey('instant-active-input'));
      expect(language, findsNothing);
      expect(find.text('markdown'), findsNothing);
      await capture('native-code-idle');
      await tester.tap(find.text(code));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(body).controller!.text, code);
      expect(
        tester.getTopLeft(language).dy,
        greaterThan(tester.getBottomLeft(body).dy),
      );
      await tester.tap(language);
      await tester.enterText(language, 'dart');
      await tester.pumpAndSettle();
      expect(vm.editor.text, source.replaceFirst('```markdown', '```dart'));
      await capture('native-code-editing');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(vm.editor.text, source);
      expect(language, findsNothing);
      vm.updateAppearance(mode: ThemeMode.dark);
      await tester.pumpAndSettle();
      await capture('native-code-dark');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
