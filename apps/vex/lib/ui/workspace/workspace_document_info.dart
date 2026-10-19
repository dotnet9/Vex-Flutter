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

/// 工具 → 字数统计：与原型 dlg-statistics 的字段一致。
Future<void> showWorkspaceStatistics(
  BuildContext context,
  WorkspaceViewModel vm,
) {
  final l = context.l10n;
  final text = vm.editor.session.text;
  final blocks = vm.editor.document.blocks;
  final minutes = (vm.editor.wordCount / 350).ceil().clamp(1, 1 << 30);
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
