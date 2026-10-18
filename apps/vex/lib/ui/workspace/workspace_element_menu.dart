import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'document_image.dart';
import 'element_editor_dialog.dart';
import 'workspace_element_entries.dart';
import 'workspace_links.dart';
import 'workspace_menu.dart';
import 'workspace_menu_widgets.dart';
import 'workspace_touch_menu.dart';
import 'workspace_view_model.dart';

class WorkspaceElementMenu extends StatefulWidget {
  const WorkspaceElementMenu({
    super.key,
    required this.vm,
    required this.onAction,
    required this.onError,
    required this.builder,
  });
  final WorkspaceViewModel vm;
  final ValueChanged<String> onAction;
  final ValueChanged<Object> onError;
  final Widget Function(ValueChanged<MarkdownContextRequest> onContextMenu)
  builder;
  @override
  State<WorkspaceElementMenu> createState() => _WorkspaceElementMenuState();
}

class _WorkspaceElementMenuState extends State<WorkspaceElementMenu> {
  final _menu = MenuController();
  final _menuFocus = FocusNode();
  final _anchor = GlobalKey();
  MarkdownTableTarget? _table;
  MarkdownElementTarget? _target;
  VoidCallback? _onEdit;
  ValueChanged<int>? _onEditAt;
  WorkspaceDocument? _document;
  bool _readOnly = false, _openingTouch = false;
  bool _keyboardMenu = false;
  List<WorkspaceMenuEntry> _entries = [];

  @override
  void dispose() {
    _menuFocus.dispose();
    super.dispose();
  }

  void _open(MarkdownContextRequest request) {
    if (_openingTouch) return;
    final vm = widget.vm;
    final table = vm.editor.tableTarget(
      offset: request.offset,
      row: request.tableRow,
      column: request.tableColumn,
    );
    final target = vm.editor.elementTarget(
      offset: request.offset,
      selection: request.selection,
    );
    _menu.close();
    setState(() {
      _table = table;
      _target = target;
      _onEdit = request.onEdit;
      _onEditAt = request.onEditAt;
      _document = vm.current;
      _readOnly = request.readOnly;
      _keyboardMenu = request.keyboard;
      _entries = table != null
          ? workspaceTableEntries(context.l10n, table, readOnly: _readOnly)
          : workspaceElementEntries(
              vm,
              target,
              readOnly: _readOnly,
              canExpand: request.onEdit != null,
            );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !target.isCurrent || !identical(vm.current, _document)) {
        return;
      }
      final touch = !const [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
      if (touch || MediaQuery.sizeOf(context).width < 700) {
        _openingTouch = true;
        unawaited(
          showWorkspaceTouchMenu(
            context,
            _entries,
            title: table != null
                ? context.l10n.table
                : context.l10n.elementActions,
          ).then((action) {
            _openingTouch = false;
            if (mounted && action != null) _run(action);
          }),
        );
      } else {
        final box = _anchor.currentContext!.findRenderObject()! as RenderBox;
        _menu.open(position: box.globalToLocal(request.position));
        if (request.keyboard) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _menu.isOpen) _menuFocus.requestFocus();
          });
        }
      }
    });
  }

  void _run(String action) {
    _menu.close();
    final target = _target;
    if (target == null) return;
    if (!identical(widget.vm.current, _document) || !target.isCurrent) {
      widget.onError(StateError(context.l10n.documentChanged));
      return;
    }
    unawaited(
      _execute(
        action,
        target,
        _document!,
        _readOnly,
        _table,
        _onEdit,
        _onEditAt,
      ).catchError((Object error) {
        if (mounted) widget.onError(error);
      }),
    );
  }

  bool _valid(MarkdownElementTarget target, WorkspaceDocument document) {
    if (!mounted) return false;
    if (!identical(widget.vm.current, document) || !target.isCurrent) {
      throw StateError(context.l10n.documentChanged);
    }
    return true;
  }

  Future<void> _execute(
    String action,
    MarkdownElementTarget target,
    WorkspaceDocument document,
    bool readOnly,
    MarkdownTableTarget? table,
    VoidCallback? onEdit,
    ValueChanged<int>? onEditAt,
  ) async {
    if (!_valid(target, document)) return;
    if (action.startsWith('element:media@')) {
      final parts = action.substring(14).split(':');
      final offset = int.tryParse(parts.first);
      if (offset == null || parts.length != 2) return;
      await _execute(
        'element:${parts.last}',
        target.controller.elementTarget(offset: offset),
        document,
        readOnly,
        null,
        null,
        onEditAt,
      );
      return;
    }
    if (action.startsWith('table:')) {
      if (table == null) return;
      final command = MarkdownTableCommand.values.byName(action.substring(6));
      if (readOnly && command != MarkdownTableCommand.copy) return;
      if (command == MarkdownTableCommand.copy) {
        await Clipboard.setData(
          ClipboardData(text: table.block.range.slice(table.source)),
        );
      } else {
        target.controller.editTable(table, command);
      }
      return;
    }
    final media = target.media, editor = target.controller;
    final selected = target.hasSelection
        ? target.selected
        : readOnly
        ? target.raw
        : '';
    if (action == 'element:copy' || action.startsWith('element:copy-')) {
      final value = switch (action) {
        'element:copy-url' => media?.url ?? '',
        'element:copy-source' => target.code,
        'element:copy-html' => markdownHtmlFragment(
          selected,
          widget.vm.markdownPreferences,
        ),
        'element:copy-plain' => markdownPlainText(selected),
        _ => selected,
      };
      await Clipboard.setData(ClipboardData(text: value));
      return;
    }
    if (action == 'element:open-link') {
      await openWorkspaceLink(widget.vm, media?.url);
      return;
    }
    if (action == 'element:preview-image' ||
        action == 'element:preview-block') {
      await showDialog<void>(
        context: context,
        builder: (context) => AppDialog(
          title: context.l10n.elementPreview,
          width: 760,
          child: action == 'element:preview-image'
              ? InteractiveViewer(
                  child: DocumentImage(
                    uri: Uri.parse(media!.url),
                    documentPath: document.path,
                    alt: media.description,
                  ),
                )
              : MarkdownReader(
                  data: target.raw,
                  labels: context.l10n.editorLabels,
                  preferences: widget.vm.markdownPreferences,
                ),
        ),
      );
      return;
    }
    if (readOnly) return;
    if (action == 'element:cut') {
      if (!target.hasSelection) return;
      await Clipboard.setData(ClipboardData(text: target.selected));
      if (!_valid(target, document)) return;
      target.replace(
        SourceRange(target.selection.start, target.selection.end),
        '',
        label: '剪切文字',
      );
      onEditAt?.call(editor.selection.extentOffset);
    } else if (action == 'element:paste' || action == 'element:paste-plain') {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!_valid(target, document) || data?.text == null) return;
      target.restoreSelection();
      var text = data!.text!;
      if (action == 'element:paste-plain' && target.textBlock) {
        text = text.replaceAllMapped(
          RegExp(r'[\\`*_{}\[\]<>#|~]'),
          (match) => '\\${match[0]}',
        );
      }
      editor.replaceSelection(
        text.replaceAll(RegExp(r'\r\n|\r|\n'), target.newline),
        label: '粘贴文字',
      );
      onEditAt?.call(editor.selection.extentOffset);
    } else if (action == 'format:link' ||
        action == 'format:image' ||
        action == 'element:edit-media' ||
        action == 'element:edit-block') {
      final inserting = action == 'format:link' || action == 'format:image';
      final result = await showElementEditor(
        context,
        target,
        image: inserting ? action == 'format:image' : null,
        onPickImage: () async {
          final asset = await widget.vm.imageAssets.pick();
          if (asset == null || !_valid(target, document)) return null;
          final raw = await widget.vm.imageAssets.markdown(
            asset,
            documentPath: document.path,
            preferences: widget.vm.imagePreferences,
          );
          if (!_valid(target, document)) return null;
          final token = markdownMediaTargets(
            raw,
            MarkdownBlock(
              MarkdownBlockKind.paragraph,
              SourceRange(0, raw.length),
              1,
            ),
          ).single;
          return (url: token.url, description: token.description);
        },
      );
      if (result == null || !_valid(target, document)) return;
      if (inserting) {
        target.insertMedia(
          result.url,
          result.description,
          title: result.title,
          image: action == 'format:image',
        );
      } else if (media != null) {
        target.editMedia(result.url, result.description, title: result.title);
      } else if (target.block.kind == MarkdownBlockKind.code) {
        target.editCode(result.source, result.language);
      } else {
        target.editFormula(result.source);
      }
    } else {
      switch (action) {
        case 'element:expand-diagram':
          onEdit?.call();
        case 'element:delete-block':
          target.deleteBlock();
        case 'element:unlink':
          target.unlink();
        case 'element:delete-selection':
          if (target.hasSelection) {
            target.replace(
              SourceRange(target.selection.start, target.selection.end),
              '',
            );
            onEditAt?.call(editor.selection.extentOffset);
          }
        case 'element:insert-above':
          target.insertParagraph(above: true);
          onEditAt?.call(editor.selection.extentOffset);
        case 'element:insert-below':
          target.insertParagraph(above: false);
          onEditAt?.call(editor.selection.extentOffset);
        case 'element:indent':
          target.indent(widget.vm.editingPreferences.indent);
        case 'element:outdent':
          target.indent(widget.vm.editingPreferences.indent, reverse: true);
        case 'element:toggle-task':
          target.toggleTask();
        default:
          if (table != null || !target.textBlock) {
            editor.select(target.block.range.end);
          } else {
            target.restoreSelection();
          }
          widget.onAction(action);
          if (target.textBlock &&
              action.startsWith('format:') &&
              !const [
                'format:image',
                'format:table',
                'format:code',
                'format:math',
                'format:rule',
                'format:footnote',
              ].contains(action)) {
            onEditAt?.call(editor.selection.extentOffset);
          }
      }
    }
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    animated: !MediaQuery.disableAnimationsOf(context),
    key: _anchor,
    controller: _menu,
    menuChildren: workspaceMenuWidgets(
      context,
      _entries,
      _run,
      firstFocusNode: _keyboardMenu ? _menuFocus : null,
    ),
    child: widget.builder(_open),
  );
}
