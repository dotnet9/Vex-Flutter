import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('measure native geometry and editing displacement', (
    tester,
  ) async {
    await windowManager.ensureInitialized();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setSize(const Size(1230, 750));
    final vm = fakeWorkspace();
    vm.editor.session.replace(
      '# 代码示例\n\n```text\nS-FlowC.slnx\n├─ 01 Application\n│  ├─ SFlowC\n└─ 99 External Dependencies\n```\n\n点击这里继续写作。\n',
    );
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TexweftApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();
    // window_manager sizes the outer window; compare actual Flutter client areas.
    for (var i = 0; i < 2; i++) {
      final actual = tester.view.physicalSize / tester.view.devicePixelRatio;
      final outer = await windowManager.getSize();
      await windowManager.setSize(
        Size(
          outer.width + 1230 - actual.width,
          outer.height + 750 - actual.height,
        ),
      );
      await tester.pumpAndSettle();
    }
    final path = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    final measurements = <String, Object?>{};
    Map<String, double> rect(Finder finder) {
      final r = tester.getRect(finder.first);
      return {'x': r.left, 'y': r.top, 'width': r.width, 'height': r.height};
    }

    Future<void> capture(String name) async {
      final code = find.text(
        'S-FlowC.slnx\n├─ 01 Application\n│  ├─ SFlowC\n└─ 99 External Dependencies',
      );
      final active = find.byKey(const ValueKey('instant-active-input'));
      measurements[name] = {
        'client': {
          'width': tester.view.physicalSize.width,
          'height': tester.view.physicalSize.height,
        },
        'layoutButton': rect(find.byTooltip(vm.strings.workspaceLayout)),
        'typographyButton': rect(find.byTooltip(vm.strings.markdownTypography)),
        if (code.evaluate().isNotEmpty) 'code': rect(code),
        if (active.evaluate().isNotEmpty) 'activeInput': rect(active),
        if (find.text('点击这里继续写作。').evaluate().isNotEmpty)
          'followingParagraph': rect(find.text('点击这里继续写作。')),
      };
      if (path == null) return;
      await Directory(path).create(recursive: true);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$path/$name.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    }

    await capture('idle');
    await tester.tap(find.text('代码示例'));
    await tester.pumpAndSettle();
    await capture('heading-edit');
    await tester.tap(find.text('点击这里继续写作。'));
    await tester.pumpAndSettle();
    await capture('paragraph-edit');
    await tester.tap(
      find.text(
        'S-FlowC.slnx\n├─ 01 Application\n│  ├─ SFlowC\n└─ 99 External Dependencies',
      ),
    );
    await tester.pumpAndSettle();
    await capture('code-edit');
    await tester.tap(find.byTooltip(vm.strings.workspaceLayout));
    await tester.pumpAndSettle();
    measurements['pickerClose'] = rect(find.byTooltip(vm.strings.closePicker));
    await capture('layout-picker');
    await tester.tap(find.byTooltip(vm.strings.closePicker));
    await tester.pumpAndSettle();
    if (path != null) {
      await File(
        '$path/geometry.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(measurements));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
