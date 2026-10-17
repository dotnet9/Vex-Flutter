import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native workspace keeps selections across toolbar actions and continues typing',
    (tester) async {
      await windowManager.ensureInitialized();
      await windowManager.setSize(const Size(1280, 800));
      final vm = fakeWorkspace();
      await vm.initialize(watchFiles: false);
      vm.editor.session.replace('# 标题\n\n待选正文。\n\n- [x] 首项\n');
      await tester.pumpWidget(TexweftApp(viewModel: vm));
      await tester.pumpAndSettle();
      final body = find.byKey(const ValueKey('instant-active-input'));
      await tester.tap(find.text('待选正文。'));
      await tester.pumpAndSettle();
      tester.widget<TextField>(body).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 2);
      await tester.pump();
      await tester.tap(find.byTooltip('加粗'));
      await tester.pumpAndSettle();
      expect(vm.editor.text, contains('**待选**正文。'));
      vm.editor.session.undo();
      await tester.pumpAndSettle();

      await tester.tap(find.text('标题').last);
      await tester.pumpAndSettle();
      await tester.enterText(body, '标题\n');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(body).controller!.text, '');
      expect(tester.widget<TextField>(body).style!.fontSize, vm.fontSize);
      await tester.enterText(body, '新段落');
      await tester.pumpAndSettle();
      expect(vm.editor.text, '# 标题\n\n新段落\n\n待选正文。\n\n- [x] 首项\n');

      vm.editor.session.replace('- [x] 首项\n');
      await tester.pumpAndSettle();
      await tester.tap(find.text('首项'));
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(body).controller!;
      input.selection = TextSelection.collapsed(offset: input.text.length);
      await tester.enterText(body, '${input.text}\n');
      await tester.pumpAndSettle();
      expect(input.text, '- [x] 首项\n- [ ] ');
      await tester.enterText(body, '${input.text}\n');
      await tester.pumpAndSettle();
      expect(input.text, '- [x] 首项\n\n');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
