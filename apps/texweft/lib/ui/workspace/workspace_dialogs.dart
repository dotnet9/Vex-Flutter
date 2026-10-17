import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/export_service.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import '../core/palette_tokens.dart';
import 'workspace_pickers.dart';
import 'workspace_view_model.dart';

Future<void> showExportDialog(BuildContext context, WorkspaceViewModel vm) =>
    showDialog<void>(
      context: context,
      builder: (context) => _ExportDialog(vm: vm),
    );

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.vm});
  final WorkspaceViewModel vm;
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  final _service = DocumentExportService();
  bool _busy = false;
  String _message = '';
  Future<void> _export(String type) async {
    final vm = widget.vm, source = widget.vm.editor.session.text;
    final colors = Theme.of(context).colorScheme,
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
              _service.html(
                source: source,
                title: stem,
                colors: colors,
                typography: typography,
                compact: compact,
              ),
            ),
          );
        case 'docx':
          bytes = _service.docx(source: source, title: stem);
        case 'png':
          bytes = await _service.mindMapPng(vm.map.root, colors);
        default:
          bytes = await _service.pdf(
            source: source,
            title: stem,
            colors: colors,
            typography: typography,
            compact: compact,
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
        );
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
          style: const TextStyle(fontSize: 12, height: 1.9),
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
                height: 36,
                onPressed: _busy ? null : () => _export(entry.$1),
              ),
          ],
        ),
        const SizedBox(height: 18),
        AppButton(
          label: context.l10n.copyHtml,
          icon: 'copy',
          onPressed: _busy
              ? null
              : () async {
                  final vm = widget.vm;
                  await Clipboard.setData(
                    ClipboardData(
                      text: _service.html(
                        source: vm.editor.session.text,
                        title: vm.current.name,
                        colors: Theme.of(context).colorScheme,
                        typography: vm.typography,
                        compact: vm.compact,
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
              style: const TextStyle(fontSize: 12, height: 1.8),
            ),
          ),
      ],
    ),
  );
}

Future<void> showAppearance(
  BuildContext context,
  WorkspaceViewModel vm,
) => showDialog<void>(
  context: context,
  builder: (context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => AppDialog(
      title: context.l10n.appearance,
      width: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.themeMode,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final item in [
                (ThemeMode.light, context.l10n.light),
                (ThemeMode.dark, context.l10n.dark),
                (ThemeMode.system, context.l10n.followSystem),
              ])
                AppButton(
                  label: item.$2,
                  bordered: true,
                  selected: vm.themeMode == item.$1,
                  onPressed: () => vm.updateAppearance(mode: item.$1),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            context.l10n.interfaceColors,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in paletteNames.entries)
                AppButton(
                  label: context.l10n.paletteName(entry.key),
                  selected: vm.palette == entry.key,
                  bordered: true,
                  onPressed: () => vm.updateAppearance(palette: entry.key),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.bodyTypography,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) =>
                TypographyChoices(vm: vm, width: constraints.maxWidth),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.l10n.compactSpacing,
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(
              context.l10n.appearancePreservesSource,
              style: const TextStyle(fontSize: 11),
            ),
            value: vm.compact,
            onChanged: (v) => vm.updateAppearance(compact: v),
          ),
        ],
      ),
    ),
  ),
);

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
              Text(
                context.l10n.summaryLength(vm.summaryLength),
                style: const TextStyle(fontSize: 12),
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
                  title: Text(item.$2, style: const TextStyle(fontSize: 12)),
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
                style: const TextStyle(fontSize: 11, height: 1.8),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: context.l10n.restoreDefaults,
                onPressed: () => vm.setSummary(
                  length: 30,
                  paragraphs: true,
                  lists: true,
                  blocks: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );

Future<void> showSettings(BuildContext context, WorkspaceViewModel vm) =>
    showDialog<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: vm,
        builder: (context, _) => AppDialog(
          title: context.l10n.settings,
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('language-setting'),
                initialValue: vm.language,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.l10n.language),
                items: [
                  for (final entry in languageNames.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => vm.updateAppearance(language: value),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.languageHint,
                style: const TextStyle(fontSize: 11, height: 1.7),
              ),
              const SizedBox(height: 22),
              Text(
                context.l10n.editor,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.sourceLineNumbers,
                  style: const TextStyle(fontSize: 12),
                ),
                value: vm.lineNumbers,
                onChanged: (v) => vm.updateAppearance(lineNumbers: v),
              ),
              Text(
                context.l10n.bodyFontSize(vm.fontSize.round()),
                style: const TextStyle(fontSize: 12),
              ),
              Slider(
                value: vm.fontSize,
                min: 12,
                max: 22,
                divisions: 10,
                onChanged: (v) => vm.updateAppearance(fontSize: v),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.localFiles,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.localFilesDescription,
                style: const TextStyle(fontSize: 12, height: 1.9),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: context.l10n.openSourceLicenses,
                icon: 'info',
                bordered: true,
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: context.l10n.appTitle,
                  applicationVersion: '0.1.0',
                ),
              ),
            ],
          ),
        ),
      ),
    );

Future<void> showAbout(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _AboutDialog(),
);

class _AboutDialog extends StatefulWidget {
  const _AboutDialog();
  @override
  State<_AboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<_AboutDialog> {
  String _update = '';
  bool _checking = false;
  Future<void> _check() async {
    setState(() {
      _checking = true;
      _update = context.l10n.checking;
    });
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(
        Uri.parse(
          'https://api.github.com/repos/dotnet9/texweft/releases/latest',
        ),
      );
      request.headers.set('User-Agent', 'Texweft/0.1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await utf8.decoder.bind(response).join();
      if (!mounted) return;
      setState(() {
        if (response.statusCode == 404) {
          _update = context.l10n.noRelease;
        } else if (response.statusCode != 200) {
          _update = context.l10n.updateHttpError(response.statusCode);
        } else {
          final data = jsonDecode(body) as Map;
          _update = context.l10n.latestVersion(data['tag_name'].toString());
        }
      });
    } catch (_) {
      if (mounted) setState(() => _update = context.l10n.githubUnavailable);
    } finally {
      client.close();
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.about,
    width: 620,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset('assets/brand/logo.svg', width: 72, height: 72),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.appTitle,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.slogan,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.nativeApplication,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.aboutDescription,
          style: const TextStyle(fontSize: 13, height: 1.9),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.author,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: context.l10n.authorWebsite,
              icon: 'ext',
              bordered: true,
              onPressed: () => launchUrl(
                Uri.parse('https://codewf.com'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            AppButton(
              label: context.l10n.githubSource,
              icon: 'code',
              bordered: true,
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/dotnet9/texweft'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            AppButton(
              label: context.l10n.releasesDownloads,
              icon: 'export',
              bordered: true,
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/dotnet9/texweft/releases'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Divider(),
        const SizedBox(height: 14),
        AppButton(
          label: _checking ? context.l10n.checking : context.l10n.checkUpdates,
          icon: 'refresh',
          onPressed: _checking ? null : _check,
        ),
        if (_update.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_update, style: const TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 12),
        Text(
          context.l10n.acknowledgements,
          style: const TextStyle(fontSize: 11, height: 1.8),
        ),
      ],
    ),
  );
}
