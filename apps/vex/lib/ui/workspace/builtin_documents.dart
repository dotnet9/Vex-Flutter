import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/l10n.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';

enum BuiltinDocument {
  thanks('鸣谢.md'),
  changelog('更新日志.md');

  const BuiltinDocument(this.filename);
  final String filename;
  String title(AppLocalizations strings) =>
      this == thanks ? strings.builtinThanks : strings.changelog;
  String get argument => '--builtin-document=$name';
  Future<String> load() =>
      rootBundle.loadString('assets/generated/documents/$filename');
  static BuiltinDocument? fromArguments(List<String> arguments) =>
      values.where((doc) => arguments.contains(doc.argument)).firstOrNull;
}

Future<void> showBuiltinDocument(
  BuildContext context,
  BuiltinDocument document, {
  Future<void> Function(String executable, List<String> arguments)?
  startProcess,
}) async {
  if (const [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ].contains(defaultTargetPlatform)) {
    final arguments = [
      document.argument,
      '--language=${context.l10n.localeName}',
      '--theme=${Theme.of(context).brightness.name}',
    ];
    if (startProcess != null) {
      await startProcess(Platform.resolvedExecutable, arguments);
    } else {
      await Process.start(
        Platform.resolvedExecutable,
        arguments,
        mode: ProcessStartMode.detached,
      );
    }
    return;
  }
  final source = await document.load();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: document.title(context.l10n),
      width: 640,
      bodyColor: documentTheme(Theme.of(context)).colorScheme.surface,
      actions: [
        AppButton(
          label: context.l10n.close,
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: SelectionArea(child: _BuiltinBody(source: source)),
    ),
  );
}

class _BuiltinBody extends StatelessWidget {
  const _BuiltinBody({required this.source});
  final String source;
  @override
  Widget build(BuildContext context) => Theme(
    data: documentTheme(Theme.of(context)),
    child: MarkdownReader(
      data: source,
      selectable: false,
      onTapLink: (_, href, _) {
        if (href == '../design/Third-Party-Licenses.html') {
          showLicensePage(context: context);
          return;
        }
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null && ['https', 'http', 'mailto'].contains(uri.scheme)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    ),
  );
}

/// A separate process loads only bundled Markdown, without a workspace, recovery
/// store or MCP server. No temporary or user-editable copy is created.
class BuiltinDocumentApp extends StatelessWidget {
  const BuiltinDocumentApp({
    super.key,
    required this.document,
    required this.source,
    this.language = 'zh',
    this.brightness = Brightness.light,
    this.windowIntegration = true,
  });
  final BuiltinDocument document;
  final String source, language;
  final Brightness brightness;
  final bool windowIntegration;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme('weft', brightness, language: language),
    locale: localeForLanguage(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            if (defaultTargetPlatform != TargetPlatform.macOS ||
                !windowIntegration)
              SizedBox(
                height: 33,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: windowIntegration
                            ? (_) => windowManager.startDragging()
                            : null,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${document.title(context.l10n)} · ${context.l10n.appTitle}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    AppCaptionButton(
                      icon: 'min',
                      tooltip: context.l10n.minimize,
                      onPressed: () {
                        if (windowIntegration) windowManager.minimize();
                      },
                    ),
                    AppCaptionButton(
                      icon: 'max',
                      tooltip: context.l10n.maximizeRestore,
                      onPressed: () async {
                        if (!windowIntegration) return;
                        if (await windowManager.isMaximized()) {
                          await windowManager.unmaximize();
                        } else {
                          await windowManager.maximize();
                        }
                      },
                    ),
                    AppCloseButton(
                      onPressed: () {
                        if (windowIntegration) windowManager.close();
                      },
                    ),
                  ],
                ),
              ),
            const Divider(),
            Expanded(
              child: ColoredBox(
                color: documentTheme(Theme.of(context)).colorScheme.surface,
                child: SelectionArea(
                  child: SingleChildScrollView(
                    key: const ValueKey('builtin-document-scroll'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 30,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: _BuiltinBody(source: source),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(),
            SizedBox(
              height: 28,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    context.l10n.builtinReadOnly,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
