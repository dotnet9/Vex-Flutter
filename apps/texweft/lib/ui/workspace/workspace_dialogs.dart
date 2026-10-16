import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/workspace.dart';
import '../core/app_widgets.dart';
import '../core/palette_tokens.dart';
import 'workspace_view_model.dart';

Future<void> showLayouts(BuildContext context, WorkspaceViewModel vm) =>
    showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: '工作区布局',
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择适合当前任务的视图组合，所有视图共享同一份内容。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final layout in WorkspaceLayout.values)
                    SizedBox(
                      width:
                          (constraints.maxWidth -
                              (constraints.maxWidth < 430 ? 8 : 24)) /
                          (constraints.maxWidth < 430 ? 2 : 4),
                      child: InkWell(
                        onTap: () {
                          vm.setLayout(layout);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: vm.layout == layout
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 47,
                                child: _LayoutMiniature(layout),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 32,
                                child: Text(
                                  layout.label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${layout.panes.length} 个视图',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              '拖动分隔线可调整视图比例。单窗口内完成写作、阅读和结构整理。',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );

class _LayoutMiniature extends StatelessWidget {
  const _LayoutMiniature(this.layout);
  final WorkspaceLayout layout;
  @override
  Widget build(BuildContext context) {
    Widget panel(String type) => Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: type == 'read'
            ? Theme.of(context).colorScheme.surfaceContainerLow
            : Theme.of(context).colorScheme.primaryContainer,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: AppGlyph(
          type == 'map'
              ? 'map'
              : type == 'read'
              ? 'eye'
              : 'edit',
          size: 11,
        ),
      ),
    );
    if (layout == WorkspaceLayout.three) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: panel('source')),
                Expanded(child: panel('read')),
              ],
            ),
          ),
          Expanded(child: panel('map')),
        ],
      );
    }
    return Row(
      children: [for (final type in layout.panes) Expanded(child: panel(type))],
    );
  }
}

Future<void> showAppearance(
  BuildContext context,
  WorkspaceViewModel vm, {
  bool typographyOnly = false,
}) => showDialog<void>(
  context: context,
  builder: (context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => AppDialog(
      title: typographyOnly ? 'Markdown 排版' : '外观与排版',
      width: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!typographyOnly) ...[
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
          ],
          const Text(
            '正文排版',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final type in MarkdownTypography.values)
                  SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: InkWell(
                      onTap: () => vm.updateAppearance(typography: type),
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        height: 150,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: vm.typography == type
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: ClipRect(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    type.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (vm.typography == type)
                                    const AppGlyph('check', size: 13),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type.description,
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(height: 7),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: MarkdownReader(
                                    data: '## 让文字有自己的节奏\n\n落笔成文，思路成形。',
                                    typography: type,
                                    fontSize: 10,
                                    compact: true,
                                    selectable: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
            SvgPicture.asset('../../logo.svg', width: 72, height: 72),
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
