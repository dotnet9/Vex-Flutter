import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/repositories/window_recovery_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/desktop_window.dart';
import 'data/services/file_service.dart';
import 'l10n/l10n.dart';
import 'ui/workspace/workspace_view_model.dart';
import 'ui/workspace/builtin_documents.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Cascadia Code',
    ], await rootBundle.loadString('assets/fonts/CascadiaCode-OFL.txt'));
  });
  final builtin = BuiltinDocument.fromArguments(arguments);
  await initializeDesktopWindow(
    nativeTitleBar: defaultTargetPlatform == TargetPlatform.macOS,
  );
  final nativeSettings = NativeSettingsRepository();
  Map<String, Object?>? preferences;
  if (builtin != null) {
    try {
      preferences = await nativeSettings.load();
    } catch (error) {
      debugPrint('Builtin document preferences could not be loaded: $error');
      preferences = {};
    }
  }
  final vm = WorkspaceViewModel(
    files: NativeDocumentFileService(),
    settings: preferences == null
        ? nativeSettings
        : SessionSettingsRepository({
            ...preferences,
            'mcp': null,
            'workspace': null,
            'guideSeen': true,
            'language':
                arguments
                    .where((a) => a.startsWith('--language='))
                    .firstOrNull
                    ?.substring(11) ??
                preferences['language'] ??
                'zh',
            'theme': arguments.contains('--theme=dark') ? 'dark' : 'light',
          }),
    recovery: WindowRecoveryRepository(),
    initialLanguage: languageForLocales(
      WidgetsBinding.instance.platformDispatcher.locales,
    ),
  );
  await vm.initialize();
  if (builtin != null) {
    vm.openBundledDocument(builtin.filename, await builtin.load());
  }
  for (final path in arguments.where((a) => !a.startsWith('-'))) {
    try {
      // 文件树右键“在新窗口打开”可能传入文件夹：新进程直接进入该文件夹。
      if (FileSystemEntity.isDirectorySync(path)) {
        await vm.openFolderPath(path);
      } else {
        await vm.openPath(path);
      }
    } catch (_) {
      /* A stale association must not prevent startup. */
    }
  }
  // 剧本：首次进入工作区自动弹出快速上手；看过一次（guideSeen 持久化）
  // 或带文档路径启动时不打扰。
  if (!vm.guideSeen &&
      builtin == null &&
      !arguments.any((argument) => !argument.startsWith('-'))) {
    vm.startGuide();
  }
  runApp(VexApp(viewModel: vm, windowIntegration: true));
}
