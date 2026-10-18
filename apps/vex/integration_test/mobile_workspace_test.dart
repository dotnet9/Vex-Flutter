import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex_editor/vex_editor.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile pickers, fonts and table insertion share the document', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    const original = '# 落笔成文\n\n手机上的中文与 English。\n\n```dart\nprint("维刻");\n```';
    vm.editor.session.replace(original);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      final directory = Platform.environment['VEX_CAPTURE_DIR'];
      if (directory == null) return;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    }

    await capture('mobile-system-font');
    await tester.tap(find.byTooltip('工作区布局'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('layout-read')));
    await tester.pumpAndSettle();
    expect(vm.layout, WorkspaceLayout.read);
    expect(find.byKey(const ValueKey('layout-picker')), findsOneWidget);
    await tester.tap(find.byTooltip('Markdown 排版'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('typography-book')));
    await tester.pumpAndSettle();
    expect(vm.typography, MarkdownTypography.book);
    await capture('mobile-typography-picker');
    await tester.tap(find.byTooltip('关闭选择面板'));
    await tester.pumpAndSettle();
    expect(vm.editor.text, original);

    vm.setLayout(WorkspaceLayout.instant);
    vm.editor.select(original.length);
    await tester.pumpAndSettle();
    final tableButton = find.byTooltip('表格');
    await tester.ensureVisible(tableButton);
    await tester.tap(tableButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('table-rows')), '2');
    await tester.enterText(find.byKey(const ValueKey('table-columns')), '4');
    await capture('mobile-table-dialog');
    await tester.tap(find.text('插入'));
    await tester.pumpAndSettle();
    expect(vm.editor.text, contains('| 标题1 | 标题2 | 标题3 | 标题4 |'));
    expect(vm.editor.text, startsWith(original));
    vm.editor.session.undo();
    await tester.pumpAndSettle();
    expect(vm.editor.text, original);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
