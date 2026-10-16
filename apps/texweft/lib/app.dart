import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

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
            title: '笺纬 Texweft',
            debugShowCheckedModeBanner: false,
            theme: appTheme(value.palette, Brightness.light),
            darkTheme: appTheme(value.palette, Brightness.dark),
            themeMode: value.mode,
            locale: value.language == 'zh_Hant'
                ? const Locale.fromSubtags(
                    languageCode: 'zh',
                    scriptCode: 'Hant',
                  )
                : Locale(value.language),
            supportedLocales: const [
              Locale('zh'),
              Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
              Locale('en'),
              Locale('ja'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: WorkspaceScreen(windowIntegration: windowIntegration),
          ),
        ),
  );
}
