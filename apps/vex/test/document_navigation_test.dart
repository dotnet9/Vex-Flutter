import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_links.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('reading navigation survives rapid layout changes', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    final source = List.generate(
      100,
      (i) => '## Heading $i\n\nText $i\n\n',
    ).join();
    vm.editor.session.replace(source);
    vm.setLayout(WorkspaceLayout.read);
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    for (final layout in [
      WorkspaceLayout.read,
      WorkspaceLayout.instant,
      WorkspaceLayout.read,
    ]) {
      vm.setLayout(layout);
      await tester.pump();
      vm.selectHeading(vm.editor.document.headings.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      vm.followAnchor('#');
      await tester.pump();
    }
    vm.editor.session.replace('Short document');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(vm.editor.text, 'Short document');
    vm.dispose();
  });

  test(
    'anchors resolve encoded Unicode and duplicates without editing content',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      const source = '# 标题\r\n\r\n## **重复**\r\n正文\r\n\r\n## 重复\r\n末尾\r\n';
      vm.editor.session.replace(source);
      expect(vm.followAnchor('#${Uri.encodeComponent('重复-1')}'), isTrue);
      expect(vm.selectedHeading, vm.editor.document.headings.last);
      final request = vm.editor.navigation.value;
      expect(vm.followAnchor('#重复-1'), isTrue);
      expect(vm.editor.navigation.value, isNot(same(request)));
      final selection = vm.editor.selection;
      expect(vm.followAnchor('#missing'), isFalse);
      expect(vm.editor.selection, selection);
      expect(vm.status, contains('missing'));
      expect(vm.followAnchor('#%E4'), isFalse);
      expect(vm.followAnchor('https://example.com/#标题'), isFalse);
      await openWorkspaceLink(vm, 'javascript:alert(1)');
      await openWorkspaceLink(vm, 'file:///private/secret');
      expect(vm.followAnchor('#'), isTrue);
      expect(vm.editor.selection.start, 0);
      expect(vm.selectedHeading, isNull);
      expect(vm.editor.text, source);
      vm.editor.session.undo();
      expect(vm.editor.text, '');
    },
  );

  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets(
      'reading link and context menu navigate in-place at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final vm = fakeWorkspace();
        final source =
            '# 文内导航\n\n[跳到末尾](#目标)\n\n'
            '${List.generate(80, (i) => '段落 $i\n\n').join()}'
            '## 目标\n\n已到达末尾\n\n';
        vm.editor.session.replace(source);
        vm.setLayout(WorkspaceLayout.read);
        await tester.pumpWidget(VexApp(viewModel: vm));
        await tester.pumpAndSettle();
        await tester.tap(find.text('跳到末尾', findRichText: true));
        await tester.pumpAndSettle();
        final target = find.byKey(
          ValueKey('read-element-${source.indexOf('## 目标')}'),
        );
        expect(target, findsOneWidget);
        expect(tester.getRect(target).top, lessThan(size.height - 100));
        expect(vm.selectedHeading?.title, '目标');
        expect(vm.layout, WorkspaceLayout.read);
        expect(find.byType(MarkdownSourceEditor), findsNothing);
        vm.followAnchor('#');
        await tester.pumpAndSettle();
        final link = find.byKey(
          ValueKey('read-element-${source.indexOf('[')}'),
        );
        if (size.width < 700) {
          await tester.longPress(link);
        } else {
          await tester.tap(
            link,
            buttons: kSecondaryMouseButton,
            kind: PointerDeviceKind.mouse,
          );
        }
        await tester.pumpAndSettle();
        final prefix = size.width < 700 ? 'touch-menu' : 'menu';
        await tester.tap(find.byKey(ValueKey('$prefix-element:open-link')));
        await tester.pumpAndSettle();
        expect(target, findsOneWidget);
        expect(tester.getRect(target).top, lessThan(size.height - 100));
        expect(vm.editor.text, source);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      },
      variant: TargetPlatformVariant.only(
        size.width < 700 ? TargetPlatform.iOS : TargetPlatform.windows,
      ),
    );
  }
}
