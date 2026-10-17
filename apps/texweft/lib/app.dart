import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
import 'ui/core/app_theme.dart';
import 'ui/workspace/workspace_screen.dart';
import 'ui/workspace/workspace_view_model.dart';

class TexweftApp extends StatelessWidget {
  const TexweftApp({
    super.key,
    required this.viewModel,
    this.windowIntegration = false,
  });
  final WorkspaceViewModel viewModel;
  final bool windowIntegration;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: viewModel,
    child:
        Selector<
          WorkspaceViewModel,
          ({String palette, ThemeMode mode, String language})
        >(
          selector: (_, vm) =>
              (palette: vm.palette, mode: vm.themeMode, language: vm.language),
          builder: (_, value, _) => MaterialApp(
            onGenerateTitle: (context) => context.l10n.appTitle,
            debugShowCheckedModeBanner: false,
            theme: appTheme(
              value.palette,
              Brightness.light,
              language: value.language,
            ),
            darkTheme: appTheme(
              value.palette,
              Brightness.dark,
              language: value.language,
            ),
            themeMode: value.mode,
            locale: localeForLanguage(value.language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: WorkspaceScreen(windowIntegration: windowIntegration),
          ),
        ),
  );
}
