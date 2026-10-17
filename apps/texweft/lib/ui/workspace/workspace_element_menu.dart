import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:texweft_editor/texweft_editor.dart';

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
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
  final _anchor = GlobalKey();
  MarkdownTableTarget? _table;
  WorkspaceDocument? _document;
  bool _readOnly = false, _openingTouch = false;
  List<WorkspaceMenuEntry> _entries = [];

  void _open(MarkdownContextRequest request) {
    if (_openingTouch) return;
    final vm = widget.vm;
    final target = vm.editor.tableTarget(
      offset: request.offset,
      row: request.tableRow,
      column: request.tableColumn,
    );
    if (target == null) return;
    _menu.close();
    setState(() {
      _table = target;
      _document = vm.current;
      _readOnly = request.readOnly;
      _entries = workspaceTableEntries(
        context.l10n,
        target,
        readOnly: _readOnly,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !target.isCurrent || !identical(vm.current, _document)) {
        return;
      }
      if (MediaQuery.sizeOf(context).width < 700) {
        _openingTouch = true;
        unawaited(
          showWorkspaceTouchMenu(
            context,
            _entries,
            title: context.l10n.table,
          ).then((action) {
            _openingTouch = false;
            if (mounted && action != null) _run(action);
          }),
        );
      } else {
        final box = _anchor.currentContext!.findRenderObject()! as RenderBox;
        _menu.open(position: box.globalToLocal(request.position));
      }
    });
  }

  void _run(String action) {
    _menu.close();
    final target = _table;
    if (target == null) return;
    if (!identical(widget.vm.current, _document) || !target.isCurrent) {
      widget.onError(StateError(context.l10n.documentChanged));
      return;
    }
    if (!action.startsWith('table:')) {
      if (!_readOnly) {
        target.controller.select(target.block.range.end);
        widget.onAction(action);
      }
      return;
    }
    final command = MarkdownTableCommand.values.byName(action.substring(6));
    if (_readOnly && command != MarkdownTableCommand.copy) return;
    if (command == MarkdownTableCommand.copy) {
      unawaited(
        Clipboard.setData(
          ClipboardData(text: target.block.range.slice(target.source)),
        ).catchError((Object error) {
          if (mounted) widget.onError(error);
        }),
      );
    } else {
      try {
        target.controller.editTable(target, command);
      } catch (error) {
        widget.onError(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    key: _anchor,
    controller: _menu,
    menuChildren: workspaceMenuWidgets(context, _entries, _run),
    child: widget.builder(_open),
  );
}
