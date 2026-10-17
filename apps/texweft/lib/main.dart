import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/repositories/recovery_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/desktop_window.dart';
import 'data/services/file_service.dart';
import 'l10n/l10n.dart';
import 'ui/workspace/workspace_view_model.dart';

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
  await initializeDesktopWindow();
  final vm = WorkspaceViewModel(
    files: NativeDocumentFileService(),
    settings: NativeSettingsRepository(),
    recovery: NativeRecoveryRepository(),
    initialLanguage: languageForLocales(
      WidgetsBinding.instance.platformDispatcher.locales,
    ),
  );
  await vm.initialize();
  for (final path in arguments.where((a) => !a.startsWith('-'))) {
    try {
      await vm.openPath(path);
    } catch (_) {
      /* A stale association must not prevent startup. */
    }
  }
  runApp(TexweftApp(viewModel: vm, windowIntegration: true));
}
