import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'context_request.dart';
import 'controller.dart';
import 'table_model.dart';

class MarkdownTableEditor extends StatefulWidget {
  const MarkdownTableEditor({
    super.key,
    required this.controller,
    required this.start,
    required this.end,
    required this.style,
    this.onContextMenu,
  });
  final MarkdownEditorController controller;
  final int start, end;
  final TextStyle style;
  final ValueChanged<MarkdownContextRequest>? onContextMenu;
  @override
  State<MarkdownTableEditor> createState() => _MarkdownTableEditorState();
}

class _MarkdownTableEditorState extends State<MarkdownTableEditor> {
  final _inputs = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};
  bool _syncing = false, _writing = false;
  List<List<TableCellSource>> get _rows => parseTableCells(
    widget.controller.text,
    widget.start,
    widget.end.clamp(widget.start, widget.controller.text.length),
  );

  void _changed(String key, int row, int column) {
    if (_syncing) return;
    final input = _inputs[key]!;
    if (input.value.composing.isValid && !input.value.composing.isCollapsed) {
      return;
    }
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
      widget.controller.select(
        cell.range.start +
            tableCellSourceOffset(encoded, input.selection.baseOffset),
        cell.range.start +
            tableCellSourceOffset(encoded, input.selection.extentOffset),
      );
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
      final input = TextEditingController(text: cell.text);
      input.addListener(() => _changed(key, row, col));
      return input;
    });
    if (!_writing && input.text != cell.text) {
      _syncing = true;
      input.value = TextEditingValue(
        text: cell.text,
        selection: TextSelection.collapsed(
          offset: input.selection.extentOffset.clamp(0, cell.text.length),
        ),
      );
      _syncing = false;
    }
    final focus = _focus.putIfAbsent(key, FocusNode.new);
    final selection = widget.controller.selection;
    if (!_writing &&
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
        child: TextField(
          key: ValueKey('table-cell-$row-$col'),
          controller: input,
          focusNode: focus,
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
                  final anchor = editable.contextMenuAnchors.primaryAnchor;
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
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
          onSubmitted: (_) => focus.nextFocus(),
          decoration: const InputDecoration(
            isDense: true,
            filled: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
