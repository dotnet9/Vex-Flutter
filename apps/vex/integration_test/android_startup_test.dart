import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/repositories/settings_repository.dart';
import 'package:vex/data/services/social_copy_service.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex/ui/workspace/workspace_menu.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('release JNI preferences can read, save and restart', (
    tester,
  ) async {
    final settings = NativeSettingsRepository();
    final original = await settings.load();
    final previousClipboard = await Clipboard.getData(Clipboard.kTextPlain);
    WorkspaceViewModel? vm;
    try {
      await settings.save({
        'palette': 'rose',
        'guideSeen': true,
        'language': 'zh',
      });
      expect((await NativeSettingsRepository().load())['palette'], 'rose');
      vm = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: NativeSettingsRepository(),
        recovery: MemoryRecovery(),
        credentials: MemoryCredentials(),
      );
      await vm.initialize(watchFiles: false);
      expect(vm.palette, 'rose');
      expect(vm.notice, isEmpty);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('workspace-more-menu')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('touch-workspace-menu'));
      final help = find.byKey(const ValueKey('touch-menu-help'));
      await tester.scrollUntilVisible(
        help,
        180,
        scrollable: find.descendant(
          of: sheet,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      final view = View.of(tester.element(sheet));
      final bottom =
          (view.physicalSize.height - view.viewPadding.bottom) /
          view.devicePixelRatio;
      expect(tester.getBottomRight(help).dy, lessThanOrEqualTo(bottom));
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('touch-menu-heading')))
            .data,
        workspaceMenuLabel(vm.strings.menuHelp),
      );
      expect(tester.takeException(), isNull);
      final copied = await SocialCopyService().prepare(
        platform: PublishingPlatform.wechat,
        source: '# 维刻\n\n**中文** & English 🌱\n',
        title: '复制验证',
        typography: MarkdownTypography.technical,
      );
      await SocialCopyService.write(copied);
      expect(
        (await Clipboard.getData(Clipboard.kTextPlain))?.text,
        copied.text,
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      vm?.dispose();
      await settings.save(original);
      await Clipboard.setData(
        previousClipboard ?? const ClipboardData(text: ''),
      );
    }
  });
}
