import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

import '../../domain/file_preferences.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_view_model.dart';

String _encodingName(DocumentEncoding encoding) => switch (encoding) {
  DocumentEncoding.utf8 => 'UTF-8',
  DocumentEncoding.utf8Bom => 'UTF-8 BOM',
  DocumentEncoding.gb18030 => 'GB18030',
  DocumentEncoding.big5 => 'Big5',
};

Widget _infoRow(BuildContext context, String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 92,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Expanded(
        child: SelectableText(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  ),
);

class WorkspaceArticleInfo extends StatefulWidget {
  const WorkspaceArticleInfo({
    super.key,
    required this.vm,
    required this.onSaveDetails,
  });
  final WorkspaceViewModel vm;
  final VoidCallback onSaveDetails;
  @override
  State<WorkspaceArticleInfo> createState() => _WorkspaceArticleInfoState();
}

class _WorkspaceArticleInfoState extends State<WorkspaceArticleInfo> {
  (String?, DateTime?)? _file;
  Future<int?>? _size;
  @override
  Widget build(BuildContext context) {
    final vm = widget.vm, l = context.l10n;
    final text = vm.editor.text, blocks = vm.editor.document.blocks;
    final file = (vm.current.path, vm.current.lastSavedAt);
    if (_file != file) {
      _file = file;
      _size = file.$1 == null
          ? Future.value(null)
          : File(file.$1!)
                .length()
                .then<int?>((value) => value, onError: (Object _) => null);
    }
    return SingleChildScrollView(
      key: ValueKey('article-info-${vm.current.id}'),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            vm.current.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Markdown · ${_encodingName(vm.current.format.encoding)}',
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l.wordCount(vm.wordCount),
            key: const ValueKey('article-word-count'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          Text(
            l.statReadingTime((vm.wordCount / 350).ceil()),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (vm.selectedWordCount case final count?)
            _infoRow(context, l.selectedWords(count), count.toString()),
          _infoRow(
            context,
            l.statSourceCharacters,
            text.characters.length.toString(),
          ),
          _infoRow(context, l.rows, text.split('\n').length.toString()),
          _infoRow(
            context,
            l.statParagraphs,
            blocks
                .where((b) => b.kind == MarkdownBlockKind.paragraph)
                .length
                .toString(),
          ),
          _infoRow(
            context,
            l.heading,
            vm.editor.document.headings.length.toString(),
          ),
          FutureBuilder<int?>(
            future: _size,
            builder: (context, snapshot) => snapshot.data == null
                ? const SizedBox.shrink()
                : _infoRow(
                    context,
                    l.propertySize,
                    l.propertyBytes(snapshot.data!),
                  ),
          ),
          if (vm.current.path case final path?)
            _infoRow(context, l.propertyLocation, path),
          const SizedBox(height: 16),
          Text(
            l.wordCountRules,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.7,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(vm.saveState, style: const TextStyle(fontSize: 12, height: 1.6)),
          const SizedBox(height: 8),
          AppButton(
            label: l.saveDetails,
            fontSize: 11.5,
            onPressed: widget.onSaveDetails,
          ),
        ],
      ),
    );
  }
}

/// 工具 → 字数统计：与原型 dlg-statistics 的字段一致。
Future<void> showWorkspaceStatistics(
  BuildContext context,
  WorkspaceViewModel vm,
) {
  final l = context.l10n;
  final text = vm.editor.session.text;
  final blocks = vm.editor.document.blocks;
  final minutes = (vm.wordCount / 350).ceil().clamp(1, 1 << 30);
  return showDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: l.statisticsTitle,
      width: 420,
      actions: [
        AppButton(label: l.close, onPressed: () => Navigator.pop(context)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(context, l.visibleWords, vm.wordCount.toString()),
          if (vm.selectedWordCount case final count?)
            _infoRow(context, l.selectedWords(count), count.toString()),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(l.wordCountRules, style: const TextStyle(fontSize: 12)),
          ),
          _infoRow(
            context,
            l.statSourceCharacters,
            text.characters.length.toString(),
          ),
          _infoRow(context, l.rows, text.split('\n').length.toString()),
          _infoRow(
            context,
            l.statParagraphs,
            blocks
                .where((block) => block.kind == MarkdownBlockKind.paragraph)
                .length
                .toString(),
          ),
          _infoRow(
            context,
            l.heading,
            blocks
                .where((block) => block.kind == MarkdownBlockKind.heading)
                .length
                .toString(),
          ),
          _infoRow(context, l.statReadingTimeLabel, l.statReadingTime(minutes)),
          _infoRow(
            context,
            l.prefEncoding,
            _encodingName(vm.current.format.encoding),
          ),
          _infoRow(
            context,
            l.statStatus,
            vm.editor.session.isDirty ? l.statModified : l.unmodified,
          ),
        ],
      ),
    ),
  );
}

/// 文件 → 文档属性（Alt+Enter）：与原型 dlg-properties 的字段一致。
Future<void> showWorkspaceProperties(
  BuildContext context,
  WorkspaceViewModel vm,
) async {
  final path = vm.current.path;
  if (path == null || !context.mounted) return;
  final l = context.l10n;
  int? size;
  try {
    size = await File(path).length();
  } catch (_) {
    // 读取失败时大小行显示占位，不阻断对话框。
  }
  if (!context.mounted) return;
  return showDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: l.documentProperties,
      width: 480,
      actions: [
        AppButton(label: l.close, onPressed: () => Navigator.pop(context)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(context, l.propertyName, vm.current.name),
          _infoRow(
            context,
            l.statStatus,
            vm.editor.session.isDirty ? l.statModified : l.unmodified,
          ),
          _infoRow(context, l.propertyFormat, 'Markdown'),
          _infoRow(
            context,
            l.prefEncoding,
            _encodingName(vm.current.format.encoding),
          ),
          if (size != null)
            _infoRow(context, l.propertySize, l.propertyBytes(size)),
          _infoRow(context, l.propertyLocation, path),
        ],
      ),
    ),
  );
}

/// 文件 → 删除文档…：确认后由调用方执行磁盘删除并关闭文档。
Future<bool> confirmDeleteDocument(BuildContext context, String name) =>
    showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.deleteDocumentConfirm(name),
        width: 460,
        actions: [
          AppButton(
            label: context.l10n.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: context.l10n.discard,
            primary: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(
          context.l10n.deleteDocumentHint,
          style: const TextStyle(fontSize: 14, height: 1.65),
        ),
      ),
    ).then((value) => value == true);
