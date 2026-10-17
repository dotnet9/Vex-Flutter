import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'context_request.dart';
import 'context_shortcuts.dart';
import 'controller.dart';
import 'editing_preferences.dart';
import 'inline_editing_controller.dart';
import 'labels.dart';
import 'markdown_preferences.dart';
import 'reader.dart';
import 'table_model.dart';

class MarkdownTableEditor extends StatefulWidget {
  const MarkdownTableEditor({
    super.key,
    required this.controller,
    required this.start,
    required this.end,
    required this.style,
    this.onContextMenu,
    this.onSelectionChanged,
    this.preferences = const MarkdownPreferences(),
    this.editingPreferences,
    this.imageBuilder,
    this.labels = const MarkdownEditorLabels(),
  });
  final MarkdownEditorController controller;
  final int start, end;
  final TextStyle style;
  final ValueChanged<MarkdownContextRequest>? onContextMenu;
  final ValueChanged<TextSelection>? onSelectionChanged;
  final MarkdownPreferences preferences;
  final MarkdownEditingPreferences? editingPreferences;
  final Widget Function(Uri uri, String? title, String? alt)? imageBuilder;
  final MarkdownEditorLabels labels;
  @override
  State<MarkdownTableEditor> createState() => _MarkdownTableEditorState();
}

class _MarkdownTableEditorState extends State<MarkdownTableEditor> {
  final _inputs = <String, MarkdownInlineEditingController>{};
  final _focus = <String, FocusNode>{};
  final _compositions = <String, (MarkdownEditorController, int)>{};
  bool _syncing = false, _writing = false;
  List<List<TableCellSource>> get _rows => parseTableCells(
    widget.controller.text,
    widget.start,
    widget.end.clamp(widget.start, widget.controller.text.length),
  );

  void _changed(String key, int row, int column) {
    if (_syncing) return;
    final input = _inputs[key]!;
    final composingBase = _compositions[key];
    if (composingBase != null &&
        composingBase !=
            (widget.controller, widget.controller.session.revision)) {
      // A stale IME commit must not overwrite a changed/switched document.
      return;
    }
    if (input.value.composing.isValid && !input.value.composing.isCollapsed) {
      _compositions.putIfAbsent(
        key,
        () => (widget.controller, widget.controller.session.revision),
      );
      return;
    }
    _compositions.remove(key);
    final rows = _rows;
    if (row >= rows.length || column >= rows[row].length) return;
    final cell = rows[row][column];
    final raw = cell.range.slice(widget.controller.text);
    final encoded = input.text == cell.text ? raw : encodeTableCell(input.text);
    _writing = true;
    try {
      if (cell.range.slice(widget.controller.text) != encoded) {
        widget.controller.session.patch(
          TextPatch(cell.range, encoded),
          label: '编辑表格单元格',
          mergeKey: 'table-${widget.start}-$key',
        );
      }
      final selection = TextSelection(
        baseOffset:
            cell.range.start +
            tableCellSourceOffset(encoded, input.selection.baseOffset),
        extentOffset:
            cell.range.start +
            tableCellSourceOffset(encoded, input.selection.extentOffset),
      );
      if (widget.onSelectionChanged case final onSelect?) {
        onSelect(selection);
      } else {
        widget.controller.select(selection.baseOffset, selection.extentOffset);
      }
    } finally {
      _writing = false;
    }
  }

  @override
  void dispose() {
    for (final input in _inputs.values) {
      input.dispose();
    }
    for (final focus in _focus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final alignments = MarkdownTable.parse(
      widget.controller.text.substring(widget.start, widget.end),
    )?.alignments;
    final columns = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: (columns * 150.0).clamp(
              constraints.maxWidth,
              double.infinity,
            ),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(color: colors.outlineVariant),
                children: [
                  for (var row = 0; row < rows.length; row++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: row == 0
                            ? colors.surfaceContainerLow
                            : colors.surface,
                      ),
                      children: [
                        for (var col = 0; col < columns; col++)
                          if (col >= rows[row].length)
                            const SizedBox(height: 44)
                          else
                            _cell(
                              rows[row][col],
                              row,
                              col,
                              columns,
                              alignments?.elementAtOrNull(col) ??
                                  MarkdownTableAlignment.none,
                            ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(
    TableCellSource cell,
    int row,
    int col,
    int columns,
    MarkdownTableAlignment alignment,
  ) {
    final key = '$row-$col';
    final input = _inputs.putIfAbsent(key, () {
      final input = MarkdownInlineEditingController(text: cell.text);
      input.addListener(() => _changed(key, row, col));
      return input;
    });
    input.preferences = widget.preferences;
    input.inlineOnly = true;
    final composing = !input.value.composing.isCollapsed;
    final preserveComposition =
        composing &&
        _compositions[key] ==
            (widget.controller, widget.controller.session.revision);
    if (!_writing && !preserveComposition) {
      _compositions.remove(key);
      if (input.text != cell.text || composing) {
        _syncing = true;
        input.value = TextEditingValue(
          text: cell.text,
          selection: TextSelection.collapsed(
            offset: input.selection.extentOffset.clamp(0, cell.text.length),
          ),
        );
        _syncing = false;
      }
    }
    final focus = _focus.putIfAbsent(key, FocusNode.new);
    final selection = widget.controller.selection;
    if (!_writing &&
        !preserveComposition &&
        _focus.values.any((node) => node.hasFocus) &&
        selection.isValid &&
        selection.start >= cell.range.start &&
        selection.end <= cell.range.end) {
      final raw = cell.range.slice(widget.controller.text);
      final local = TextSelection(
        baseOffset: tableCellDisplayOffset(
          raw,
          selection.baseOffset - cell.range.start,
        ),
        extentOffset: tableCellDisplayOffset(
          raw,
          selection.extentOffset - cell.range.start,
        ),
      );
      if (!focus.hasFocus || input.selection != local) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.controller.selection != selection) return;
          _syncing = true;
          input.selection = local;
          focus.requestFocus();
          _syncing = false;
        });
      }
    }
    return FocusTraversalOrder(
      order: NumericFocusOrder((row * columns + col).toDouble()),
      child: Listener(
        onPointerDown: widget.onContextMenu == null
            ? null
            : (event) {
                if (event.buttons == kSecondaryMouseButton) {
                  widget.onContextMenu!(
                    MarkdownContextRequest(
                      offset: cell.range.start,
                      position: event.position,
                      tableRow: row,
                      tableColumn: col,
                    ),
                  );
                }
              },
        child: ListenableBuilder(
          listenable: focus,
          builder: (context, _) => MarkdownContextShortcuts(
            onShow: widget.onContextMenu == null
                ? null
                : () {
                    if (!input.value.composing.isCollapsed) return false;
                    final position = markdownCaretMenuPosition(context);
                    if (position == null) return false;
                    widget.onContextMenu!(
                      MarkdownContextRequest(
                        offset: cell.range.start,
                        position: position,
                        selection: widget.controller.selection,
                        keyboard: true,
                        tableRow: row,
                        tableColumn: col,
                      ),
                    );
                    return true;
                  },
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Opacity(
                  opacity: focus.hasFocus ? 1 : 0,
                  alwaysIncludeSemantics: true,
                  child: TextField(
                    key: ValueKey('table-cell-$row-$col'),
                    controller: input,
                    focusNode: focus,
                    maxLines: null,
                    textInputAction: TextInputAction.next,
                    style: widget.style.copyWith(
                      fontWeight: row == 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                    textAlign: switch (alignment) {
                      MarkdownTableAlignment.center => TextAlign.center,
                      MarkdownTableAlignment.right => TextAlign.right,
                      _ => TextAlign.left,
                    },
                    contextMenuBuilder: widget.onContextMenu == null
                        ? null
                        : (context, editable) {
                            final anchor =
                                editable.contextMenuAnchors.primaryAnchor;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              editable.hideToolbar();
                              widget.onContextMenu!(
                                MarkdownContextRequest(
                                  offset: cell.range.start,
                                  position: anchor,
                                  tableRow: row,
                                  tableColumn: col,
                                ),
                              );
                            });
                            return const SizedBox.shrink();
                          },
                    inputFormatters: [
                      FilteringTextInputFormatter.singleLineFormatter,
                    ],
                    onSubmitted: (_) => focus.nextFocus(),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (!focus.hasFocus)
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: MarkdownReader(
                          key: ValueKey('table-display-$row-$col'),
                          data: cell.text,
                          inline: true,
                          selectable: false,
                          bodyStyle: widget.style.copyWith(
                            fontWeight: row == 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          inlineAlignment: switch (alignment) {
                            MarkdownTableAlignment.center =>
                              WrapAlignment.center,
                            MarkdownTableAlignment.right => WrapAlignment.end,
                            _ => WrapAlignment.start,
                          },
                          preferences: widget.preferences,
                          editingPreferences: widget.editingPreferences,
                          imageBuilder: widget.imageBuilder,
                          labels: widget.labels,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
