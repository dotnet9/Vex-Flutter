import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/ui/workspace/workspace_sidebar.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'directory search opens one document and restores collapsed folders',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      final files = vm.files as MemoryFiles;
      files.content.addAll({
        '/notes/文章.md': '# 文章',
        '/notes/专题/子目录/数学.md': '# 数学',
        '/notes/专题/流程.md': '# 流程',
      });
      files.folderDirectories = ['/notes/专题', '/notes/专题/子目录', '/notes/空目录'];
      await tester.pumpWidget(TexweftApp(viewModel: vm));
      await vm.openFolder();
      await tester.pumpAndSettle();
      final nested = find.descendant(
        of: find.byType(WorkspaceSidebar),
        matching: find.text('数学.md'),
      );
      expect(find.text('空目录'), findsOneWidget);
      expect(nested, findsOneWidget);
      await tester.tap(find.text('专题'));
      await tester.pumpAndSettle();
      expect(nested, findsNothing);
      final search = find.byKey(const ValueKey('sidebar-search'));
      await tester.enterText(search, '数学');
      await tester.pumpAndSettle();
      expect(nested, findsOneWidget);
      expect(find.text('流程.md'), findsNothing);
      await tester.tap(nested);
      await tester.pumpAndSettle();
      expect(vm.current.path, '/notes/专题/子目录/数学.md');
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(vm.filter, isEmpty);
      expect(nested, findsNothing);
      await tester.tap(find.text('专题'));
      await tester.pumpAndSettle();
      expect(nested, findsOneWidget);
      expect(vm.documents, hasLength(1));
      await tester.tap(nested);
      await tester.pumpAndSettle();
      expect(vm.documents, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
