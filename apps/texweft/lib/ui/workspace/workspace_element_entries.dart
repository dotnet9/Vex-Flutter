import 'package:texweft_editor/texweft_editor.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'workspace_menu.dart';
import 'workspace_view_model.dart';

List<WorkspaceMenuEntry> workspaceElementEntries(
  WorkspaceViewModel vm,
  MarkdownElementTarget target, {
  required bool readOnly,
  bool canExpand = false,
}) {
  final l = vm.strings, selected = target.hasSelection, editable = !readOnly;
  const divider = WorkspaceMenuEntry.separator();
  WorkspaceMenuEntry item(
    String id,
    String label, {
    bool enabled = true,
    String? icon,
  }) => WorkspaceMenuEntry('element:$id', label, enabled: enabled, icon: icon);
  WorkspaceMenuEntry group(
    String id,
    String label,
    List<WorkspaceMenuEntry> children, {
    bool toolbar = false,
  }) => WorkspaceMenuEntry(id, label, children: children, toolbar: toolbar);
  final menus = workspaceMenus(vm, macOS: false, desktop: false, maxPanes: 1);
  final paragraph = menus.firstWhere((m) => m.id == 'paragraph');
  final format = menus.firstWhere((m) => m.id == 'format');
  final media = target.media;
  final code = target.block.kind == MarkdownBlockKind.code;
  final math = target.block.kind == MarkdownBlockKind.math;
  return [
    if (media != null) ...[
      item(
        media.image ? 'preview-image' : 'open-link',
        media.image ? l.elementPreviewImage : l.elementOpenLink,
        icon: media.image ? 'image' : 'link',
      ),
      item('copy-url', l.elementCopyUrl, icon: 'copy'),
      if (editable) ...[
        item(
          'edit-media',
          media.image ? l.elementEditImage : l.elementEditLink,
        ),
        item(
          'unlink',
          media.image ? l.elementDeleteImage : l.elementUnlink,
          icon: media.image ? 'trash' : 'link',
        ),
      ],
      divider,
    ],
    if (media == null && target.mediaItems.length > 1) ...[
      for (final token in target.mediaItems)
        group(
          'element-media-${token.range.start}',
          token.description.isEmpty ? token.url : token.description,
          [
            for (final entry in workspaceElementEntries(
              vm,
              vm.editor.elementTarget(offset: token.range.start),
              readOnly: readOnly,
            ).takeWhile((entry) => !entry.isSeparator))
              WorkspaceMenuEntry(
                'element:media@${token.range.start}:${entry.id.substring(8)}',
                entry.label,
                icon: entry.icon,
              ),
          ],
        ),
      divider,
    ],
    if (code || math) ...[
      if (target.diagram || math)
        item('preview-block', l.elementPreview, icon: 'eye'),
      item('copy-source', l.elementCopySource, icon: 'copy'),
      if (editable) ...[
        if (target.diagram && canExpand)
          item('expand-diagram', l.elementExpandDiagram),
        item(
          'edit-block',
          math
              ? l.elementEditMath
              : target.diagram
              ? l.elementEditDiagram
              : l.elementEditCode,
        ),
        item('delete-block', l.elementDeleteBlock, icon: 'trash'),
      ],
      divider,
    ],
    if (target.block.kind == MarkdownBlockKind.table) ...[
      group(
        'element-table',
        l.table,
        workspaceTableEntries(
          l,
          vm.editor.tableTarget(offset: target.offset),
          readOnly: readOnly,
        ),
      ),
      divider,
    ],
    group('element-clipboard-tools', '', [
      item('cut', l.cut, enabled: editable && selected, icon: 'scissors'),
      item('copy', l.copy, enabled: selected, icon: 'copy'),
      item('paste', l.paste, enabled: editable, icon: 'clipboard'),
      item(
        'delete-selection',
        l.elementDeleteSelection,
        enabled: editable && selected,
        icon: 'trash',
      ),
    ], toolbar: true),
    group('element-copy-as', l.elementClipboardAs, [
      item(
        'copy-markdown',
        l.elementCopyMarkdown,
        enabled: selected || readOnly,
      ),
      item('copy-html', l.copyHtml, enabled: selected || readOnly),
      item('copy-plain', l.elementCopyPlain, enabled: selected || readOnly),
      divider,
      item('paste-plain', l.elementPastePlain, enabled: editable),
    ]),
    if (editable) ...[
      if (target.textBlock) ...[
        group('element-format-tools', '', [
          for (final entry in [
            ('format:bold', l.bold, 'bold'),
            ('format:italic', l.italic, 'italic'),
            ('format:inline-code', l.inlineCode, 'inline-code'),
            ('format:link', l.link, 'link'),
          ])
            WorkspaceMenuEntry(
              entry.$1,
              entry.$2,
              enabled: selected || entry.$1 == 'format:link',
              icon: entry.$3,
            ),
        ], toolbar: true),
        group(
          'element-paragraph',
          l.elementParagraphType,
          paragraph.children.take(12).toList(),
        ),
        group('element-format', l.menuFormat, format.children),
      ],
      if (target.block.kind == MarkdownBlockKind.list) ...[
        item('indent', l.elementIndent),
        item('outdent', l.elementOutdent, enabled: target.canOutdent),
        if (target.task) item('toggle-task', l.elementToggleTask),
      ],
      group('element-insert', workspaceMenuLabel(l.menuInsert), [
        WorkspaceMenuEntry('format:link', l.link),
        WorkspaceMenuEntry('format:image', l.image),
        WorkspaceMenuEntry('format:table', l.insertTable),
        ...paragraph.children
            .skip(14)
            .where((item) => item.id != 'format:footnote'),
        divider,
        item('insert-above', l.elementInsertAbove),
        item('insert-below', l.elementInsertBelow),
      ]),
      if (!code && !math) ...[
        divider,
        item('delete-block', l.elementDeleteBlock, icon: 'trash'),
      ],
    ],
  ];
}
