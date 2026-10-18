import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:vex_mindmap/vex_mindmap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/export_service.dart';
import '../../data/services/update_service.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import '../core/app_theme.dart';
import 'workspace_pickers.dart';
import 'workspace_view_model.dart';
import 'builtin_documents.dart';
import 'preferences_dialog.dart';

Future<void> showExportDialog(
  BuildContext context,
  WorkspaceViewModel vm, {
  String? type,
}) => showDialog<void>(
  context: context,
  builder: (context) => _ExportDialog(vm: vm, type: type),
);

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.vm, this.type});
  final WorkspaceViewModel vm;
  final String? type;
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  final _service = DocumentExportService();
  bool _busy = false;
  String _message = '';
  @override
  void initState() {
    super.initState();
    if (widget.type != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _export(widget.type!);
      });
    }
  }

  Future<void> _export(String type) async {
    final vm = widget.vm, source = widget.vm.editor.session.text;
    final colors = documentTheme(Theme.of(context)).colorScheme,
        typography = vm.typography,
        compact = vm.compact;
    final stem = vm.current.name.replaceFirst(
      RegExp(r'\.(md|markdown|txt)$', caseSensitive: false),
      '',
    );
    setState(() {
      _busy = true;
      _message = context.l10n.generating;
    });
    try {
      Uint8List bytes;
      switch (type) {
        case 'md':
          bytes = Uint8List.fromList(utf8.encode(source));
        case 'html':
          bytes = Uint8List.fromList(
            utf8.encode(
              await _service.html(
                source: source,
                title: stem,
                documentPath: vm.current.path,
                colors: colors,
                typography: typography,
                compact: compact,
                styled: vm.exportPreferences.htmlStyle,
                watermark: vm.watermark,
                markdown: vm.markdownPreferences,
              ),
            ),
          );
        case 'docx':
          bytes = await _service.docx(
            source: source,
            title: stem,
            documentPath: vm.current.path,
            markdown: vm.markdownPreferences,
          );
        case 'png':
          bytes = await _service.mindMapPng(
            vm.map.root,
            colors,
            layout: vm.map.layout,
          );
        default:
          bytes = await _service.pdf(
            source: source,
            title: stem,
            documentPath: vm.current.path,
            colors: colors,
            typography: typography,
            compact: compact,
            preferences: vm.exportPreferences,
            watermark: vm.watermark,
            markdown: vm.markdownPreferences,
          );
      }
      if (type == 'print') {
        final printed = await Printing.layoutPdf(
          name: stem,
          onLayout: (_) async => bytes,
        );
        if (mounted) {
          setState(
            () => _message = printed
                ? context.l10n.sentToPrinter
                : context.l10n.printCancelled,
          );
        }
      } else {
        final path = await vm.files.saveAs(
          '$stem.$type',
          bytes,
          dialogTitle: vm.strings.saveNamedFile('$stem.$type'),
          initialDirectory: vm.exportPreferences.folder.trim().isNotEmpty
              ? vm.exportPreferences.folder.trim()
              : vm.current.path == null
              ? null
              : p.dirname(vm.current.path!),
        );
        if (path != null && vm.exportPreferences.openAfterExport) {
          final result = await OpenFilex.open(path);
          if (result.type != ResultType.done) throw StateError(result.message);
        }
        if (mounted) {
          setState(
            () => _message = path == null
                ? context.l10n.exportCancelled
                : context.l10n.exportedFile('$stem.$type'),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = context.l10n.exportFailed(error.toString()));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.exportShare,
    width: 540,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.exportDescription,
          style: const TextStyle(fontSize: 14, height: 1.9),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final entry in [
              ('md', 'Markdown', 'file'),
              ('html', context.l10n.htmlPage, 'code'),
              ('pdf', context.l10n.pdfDocument, 'file'),
              ('docx', context.l10n.wordDocument, 'file'),
              ('png', context.l10n.mindMapPng, 'map'),
              ('print', context.l10n.systemPrint, 'print'),
            ])
              AppButton(
                label: entry.$2,
                icon: entry.$3,
                bordered: true,
                selected: widget.vm.exportPreferences.format == entry.$1,
                height: 36,
                onPressed: _busy ? null : () => _export(entry.$1),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.l10n.watermarkExport,
            style: const TextStyle(fontSize: 14),
          ),
          value: widget.vm.watermark.export,
          onChanged: _busy
              ? null
              : (value) =>
                    setState(() => widget.vm.updateWatermark(export: value)),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: context.l10n.copyHtml,
          icon: 'copy',
          onPressed: _busy
              ? null
              : () async {
                  final vm = widget.vm;
                  await Clipboard.setData(
                    ClipboardData(
                      text: await _service.html(
                        source: vm.editor.session.text,
                        title: vm.current.name,
                        documentPath: vm.current.path,
                        colors: Theme.of(context).colorScheme,
                        typography: vm.typography,
                        compact: vm.compact,
                        styled: vm.exportPreferences.htmlStyle,
                        watermark: vm.watermark,
                        markdown: vm.markdownPreferences,
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() => _message = context.l10n.htmlCopied);
                  }
                },
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(
              _message,
              style: const TextStyle(fontSize: 14, height: 1.8),
            ),
          ),
      ],
    ),
  );
}

Future<void> showAppearance(BuildContext context, WorkspaceViewModel vm) =>
    showPreferences(context, vm, category: PreferenceCategory.appearance);

Future<void> showSummarySettings(BuildContext context, WorkspaceViewModel vm) =>
    showDialog<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: vm,
        builder: (context, _) => AppDialog(
          title: context.l10n.summarySettings,
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) =>
                    MindMapLayoutChoices(vm: vm, width: constraints.maxWidth),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.summaryLength(vm.summaryLength),
                style: const TextStyle(fontSize: 14),
              ),
              Slider(
                value: vm.summaryLength.toDouble(),
                min: 1,
                max: 120,
                divisions: 119,
                onChanged: (v) => vm.setSummary(length: v.round()),
              ),
              for (final item in [
                (vm.paragraphs, context.l10n.paragraphs, 'p'),
                (vm.lists, context.l10n.lists, 'l'),
                (vm.blocks, context.l10n.quotesCodeTables, 'b'),
              ])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item.$2, style: const TextStyle(fontSize: 14)),
                  value: item.$1,
                  onChanged: (v) => vm.setSummary(
                    paragraphs: item.$3 == 'p' ? v : null,
                    lists: item.$3 == 'l' ? v : null,
                    blocks: item.$3 == 'b' ? v : null,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                context.l10n.summaryDescription,
                style: const TextStyle(fontSize: 12, height: 1.8),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: context.l10n.restoreDefaults,
                onPressed: () => vm.setSummary(
                  length: 30,
                  paragraphs: true,
                  lists: true,
                  blocks: false,
                  mode: MindMapLayoutMode.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );

Future<void> showSettings(BuildContext context, WorkspaceViewModel vm) =>
    showPreferences(context, vm);

Future<void> showAbout(BuildContext context, {UpdateChecker? updates}) =>
    showDialog<void>(
      context: context,
      builder: (context) => _AboutDialog(updates: updates),
    );

Future<PackageInfo?> _packageInfo() async {
  try {
    return await PackageInfo.fromPlatform();
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

String _version(PackageInfo info) => info.buildNumber.isEmpty
    ? info.version
    : '${info.version}+${info.buildNumber}';

Future<void> _showLicenses(BuildContext context) async {
  final info = await _packageInfo();
  if (!context.mounted) return;
  showLicensePage(
    context: context,
    applicationName: context.l10n.appTitle,
    applicationVersion: info == null ? null : _version(info),
    applicationLegalese: 'Copyright © 2026 沙漠尽头的狼 / CodeWF\nVex · MIT License',
  );
}

class _AboutDialog extends StatefulWidget {
  const _AboutDialog({this.updates});
  final UpdateChecker? updates;
  @override
  State<_AboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<_AboutDialog> {
  late final Future<PackageInfo?> _info = _packageInfo();
  late final UpdateChecker _updates = widget.updates ?? GitHubUpdateChecker();
  Uri _release = UpdateCheckResult.releases;
  String _update = '';
  bool _checking = false;
  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _update = context.l10n.checking;
      _release = UpdateCheckResult.releases;
    });
    try {
      final info = await _info;
      if (!mounted) return;
      final result = await _updates.check(info?.version);
      if (!mounted) return;
      setState(() {
        _release = result.releasePage;
        _update = switch (result.status) {
          UpdateStatus.noRelease => context.l10n.noRelease,
          UpdateStatus.current => context.l10n.updateCurrent,
          UpdateStatus.available => context.l10n.updateAvailable(result.tag!),
          UpdateStatus.localNewer => context.l10n.updateLocalNewer,
          UpdateStatus.unknownCurrent => context.l10n.latestVersion(
            result.tag!,
          ),
        };
      });
    } on UpdateHttpException catch (error) {
      if (mounted) {
        setState(
          () => _update = context.l10n.updateHttpError(error.statusCode),
        );
      }
    } on FormatException {
      if (mounted) setState(() => _update = context.l10n.updateInvalidResponse);
    } catch (_) {
      if (mounted) setState(() => _update = context.l10n.githubUnavailable);
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        _toast(_update);
      }
    }
  }

  @override
  void dispose() {
    _updates.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.about,
    width: 420,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 24),
          child: Row(
            children: [
              SvgPicture.asset('assets/brand/logo.svg', width: 64, height: 64),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.appTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.l10n.slogan,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _row(
          context.l10n.aboutVersionLabel,
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              FutureBuilder<PackageInfo?>(
                future: _info,
                builder: (context, snapshot) => AppButton(
                  key: const ValueKey('about-version'),
                  label: snapshot.data == null
                      ? 'dev'
                      : _version(snapshot.data!),
                  tooltip: context.l10n.releasesDownloads,
                  height: 28,
                  padding: 0,
                  onPressed: () async {
                    try {
                      if (await launchUrl(
                        _release,
                        mode: LaunchMode.externalApplication,
                      )) {
                        return;
                      }
                    } catch (_) {
                      /* A missing browser must not dismiss About. */
                    }
                    if (context.mounted) _toast(context.l10n.githubUnavailable);
                  },
                ),
              ),
              AppButton(
                label: context.l10n.changelog,
                height: 28,
                padding: 0,
                onPressed: () =>
                    showBuiltinDocument(context, BuiltinDocument.changelog),
              ),
              AppButton(
                key: const ValueKey('about-check-updates'),
                label: _checking
                    ? context.l10n.checking
                    : context.l10n.checkUpdates,
                height: 28,
                padding: 0,
                onPressed: _checking ? null : _check,
              ),
            ],
          ),
        ),
        _row(
          context.l10n.aboutAuthorLabel,
          Text(context.l10n.author, style: const TextStyle(fontSize: 14)),
        ),
        _row(
          context.l10n.aboutLicenseLabel,
          AppButton(
            label: 'MIT License',
            height: 28,
            padding: 0,
            onPressed: () => _showLicenses(context),
          ),
        ),
        _row(
          context.l10n.aboutLinksLabel,
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _link(context.l10n.officialWebsite, 'https://codewf.com'),
              _link(
                context.l10n.githubSource,
                'https://github.com/dotnet9/Vex-Flutter',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Divider(),
        const SizedBox(height: 14),
        const Text(
          'Copyright © 2026 Vex(维刻)\nFlutter / Dart',
          style: TextStyle(fontSize: 12, height: 1.8),
        ),
      ],
    ),
  );

  Widget _row(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ],
    ),
  );
  Widget _link(String label, String url) => AppButton(
    label: label,
    height: 28,
    padding: 0,
    onPressed: () =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
  );
}
