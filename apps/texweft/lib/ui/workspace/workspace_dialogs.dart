import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';

import '../../data/services/export_service.dart';
import '../core/app_widgets.dart';
import '../core/palette_tokens.dart';
import 'workspace_view_model.dart';
import 'workspace_pickers.dart';

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
      _message = '正在生成…';
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
          setState(() => _message = printed ? '已发送到系统打印窗口。' : '已取消打印。');
        }
      } else {
        final path = await vm.files.saveAs('$stem.$type', bytes);
        if (mounted) {
          setState(
            () => _message = path == null ? '已取消导出。' : '已导出 $stem.$type',
          );
        }
      }
    } catch (error) {
      if (mounted) setState(() => _message = '导出失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: '导出与分享',
    width: 540,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '将当前内容保存为独立文件。HTML 保留所选配色与排版，导图图片包含完整结构。',
          style: TextStyle(fontSize: 12, height: 1.9),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final entry in [
              ('md', 'Markdown', 'file'),
              ('html', 'HTML 页面', 'code'),
              ('pdf', 'PDF 文档', 'file'),
              ('docx', 'Word 文档', 'file'),
              ('png', '导图 PNG', 'map'),
              ('print', '系统打印', 'print'),
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
          label: '复制 HTML 源码',
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
                  if (mounted) setState(() => _message = '已复制 HTML 源码。');
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

Future<void> showAppearance(BuildContext context, WorkspaceViewModel vm) =>
    showDialog<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: vm,
        builder: (context, _) => AppDialog(
          title: '外观与排版',
          width: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '明暗模式',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in [
                    (ThemeMode.light, '浅色'),
                    (ThemeMode.dark, '深色'),
                    (ThemeMode.system, '跟随系统'),
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
              const Text(
                '界面配色',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in paletteNames.entries)
                    AppButton(
                      label: entry.value,
                      selected: vm.palette == entry.key,
                      bordered: true,
                      onPressed: () => vm.updateAppearance(palette: entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '正文排版',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) =>
                    TypographyChoices(vm: vm, width: constraints.maxWidth),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('紧凑间距', style: TextStyle(fontSize: 12)),
                subtitle: const Text(
                  '排版与配色不会改变 Markdown 原文。',
                  style: TextStyle(fontSize: 11),
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
          title: '导图摘要设置',
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '摘要长度：${vm.summaryLength} 字',
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
                (vm.paragraphs, '段落正文', 'p'),
                (vm.lists, '列表内容', 'l'),
                (vm.blocks, '引用、代码和表格', 'b'),
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
              const Text(
                '摘要只影响导图显示。点击节点可查看并编辑整节正文。',
                style: TextStyle(fontSize: 11, height: 1.8),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: '恢复默认',
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
          title: '设置',
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('编辑器', style: TextStyle(fontWeight: FontWeight.w600)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('源码行号', style: TextStyle(fontSize: 12)),
                value: vm.lineNumbers,
                onChanged: (v) => vm.updateAppearance(lineNumbers: v),
              ),
              Text(
                '正文字号：${vm.fontSize.round()} px',
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
              const Text('本地文件', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                '编辑时自动保留恢复草稿。保存会写入原文件；检测到其他程序的修改时，会先提示你处理。移动设备通过系统文件选择器保存。',
                style: TextStyle(fontSize: 12, height: 1.9),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: '开源组件许可',
                icon: 'info',
                bordered: true,
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: '笺纬 Texweft',
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
      _update = '正在检查…';
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
          _update = '尚无已发布的正式版本。';
        } else if (response.statusCode != 200) {
          _update = '检查失败（HTTP ${response.statusCode}），可前往发布页查看。';
        } else {
          final data = jsonDecode(body) as Map;
          _update = 'GitHub 最新版本：${data['tag_name']}';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _update = '暂时无法连接 GitHub，可稍后重试。');
    } finally {
      client.close();
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: '关于笺纬',
    width: 620,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset('assets/brand/logo.svg', width: 72, height: 72),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '笺纬 Texweft',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 5),
                  Text('落笔成文，思路成形。', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 5),
                  Text('0.1.0 · Flutter 原生应用', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          '把 Markdown 写作、阅读与思维导图放在同一个工作区。内容保存在本地，使用开放的文件格式。',
          style: TextStyle(fontSize: 13, height: 1.9),
        ),
        const SizedBox(height: 20),
        const Text(
          '沙漠尽头的狼 / CodeWF',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: '作者网站',
              icon: 'ext',
              bordered: true,
              onPressed: () => launchUrl(
                Uri.parse('https://codewf.com'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            AppButton(
              label: 'GitHub 源码',
              icon: 'code',
              bordered: true,
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/dotnet9/texweft'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            AppButton(
              label: '发布与下载',
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
          label: _checking ? '正在检查…' : '检查更新',
          icon: 'refresh',
          onPressed: _checking ? null : _check,
        ),
        if (_update.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_update, style: const TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 12),
        const Text(
          '开源致谢：Flutter、Dart、Vex 及各开源组件。MIT License。',
          style: TextStyle(fontSize: 11, height: 1.8),
        ),
      ],
    ),
  );
}
