import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:url_launcher/url_launcher.dart';

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
      child: SelectionArea(
        child: Theme(
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
              if (uri != null &&
                  ['https', 'http', 'mailto'].contains(uri.scheme)) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      ),
    ),
  );
}
