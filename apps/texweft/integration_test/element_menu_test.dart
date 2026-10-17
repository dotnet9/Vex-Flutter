import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/data/services/desktop_window.dart';
import 'package:texweft/domain/workspace.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native element menus, edit dialogs and source context', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    await windowManager.setMinimumSize(const Size(320, 568));
    final vm = fakeWorkspace(), boundary = GlobalKey();
    await vm.initialize(watchFiles: false);
    const source =
        '# 当前元素操作\n\n[维刻官网](https://vex.codewf.com)\n\n'
        '- [ ] 整理写作思路\n\n```dart\nfinal idea = "写下想法，看见脉络";\n```\n';
    vm.editor.session.replace(source);
    vm.editor.session.markSaved();
    vm.setLayout(WorkspaceLayout.instant);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TexweftApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();
    final directory = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      if (directory == null) return;
      await Directory(directory).create(recursive: true);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$directory/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }

    for (final size in [const Size(1280, 900), const Size(390, 844)]) {
      for (var i = 0; i < 3; i++) {
        final actual = tester.view.physicalSize / tester.view.devicePixelRatio;
        final outer = await windowManager.getSize();
        await windowManager.setSize(
          Size(
            outer.width + size.width - actual.width,
            outer.height + size.height - actual.height,
          ),
        );
        await tester.pumpAndSettle();
      }
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        vm.updateAppearance(mode: mode);
        await tester.pumpAndSettle();
        final prefix = '${size.width.toInt()}-${mode.name}';
        final link = find.byKey(
          ValueKey('element-block-${source.indexOf('[')}'),
        );
        await tester.tap(
          link,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        await capture('$prefix-link-context');
        final key = size.width < 700 ? 'touch-menu' : 'menu';
        await tester.tap(find.byKey(ValueKey('$key-element:edit-media')));
        await tester.pumpAndSettle();
        await capture('$prefix-link-dialog');
        await tester.tap(find.text(vm.strings.cancel));
        await tester.pumpAndSettle();
        if (size.width > 700) {
          final code = find.byKey(
            ValueKey('element-block-${source.indexOf('```')}'),
          );
          await tester.tap(
            code,
            buttons: kSecondaryMouseButton,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pumpAndSettle();
          await capture('$prefix-code-context');
          await tester.tap(
            find.byKey(const ValueKey('menu-element:edit-block')),
          );
          await tester.pumpAndSettle();
          await capture('$prefix-code-dialog');
          await tester.tap(find.text(vm.strings.cancel));
          await tester.pumpAndSettle();
          vm.setLayout(WorkspaceLayout.source);
          vm.editor.select(source.indexOf('final'));
          vm.editor.sourceFocus.requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.f10);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('menu-element:copy-source')),
            findsOneWidget,
          );
          await capture('$prefix-keyboard-context');
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(
            (await Clipboard.getData(Clipboard.kTextPlain))?.text,
            'final idea = "写下想法，看见脉络";',
          );
          expect(vm.editor.sourceFocus.hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(vm.editor.sourceFocus.hasFocus, isTrue);
          await tester.tap(
            find.byType(MarkdownSourceEditor),
            buttons: kSecondaryMouseButton,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('menu-element:copy-source')),
            findsOneWidget,
          );
          await capture('$prefix-source-context');
          await tester.tapAt(const Offset(30, 170));
          await tester.pumpAndSettle();
          vm.setLayout(WorkspaceLayout.instant);
          await tester.pumpAndSettle();
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
