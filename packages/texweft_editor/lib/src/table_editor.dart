import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'controller.dart';

/// A cell keeps its source range, including escaped pipes and code spans.
final class TableCellSource {
  const TableCellSource(this.range, this.text);
  final SourceRange range;
  final String text;
}

List<List<TableCellSource>> parseTableCells(String source, int start, int end) {
  final rows = <List<TableCellSource>>[];
  final lines = RegExp(r'[^\r\n]+').allMatches(source.substring(start, end));
  for (final line in lines) {
    if (rows.length == 1 &&
        RegExp(r'^\s*\|?\s*:?-{3,}').hasMatch(line.group(0)!)) {
      continue;
    }
    final value = line.group(0)!;
    final dividers = <int>[];
    var escaped = false, ticks = 0;
    for (var i = 0; i < value.length; i++) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (value[i] == r'\') {
        escaped = true;
        continue;
      }
      if (value[i] == '`') {
        var count = 1;
        while (i + count < value.length && value[i + count] == '`') {
          count++;
        }
        ticks = ticks == count
            ? 0
            : ticks == 0
            ? count
            : ticks;
        i += count - 1;
      } else if (value[i] == '|' && ticks == 0) {
        dividers.add(i);
      }
    }
    final boundaries = [-1, ...dividers, value.length];
    final row = <TableCellSource>[];
    for (var i = 0; i + 1 < boundaries.length; i++) {
      var left = boundaries[i] + 1, right = boundaries[i + 1];
      if ((i == 0 || i == boundaries.length - 2) &&
          value.substring(left, right).trim().isEmpty &&
          dividers.isNotEmpty) {
        continue;
      }
      while (left < right && value[left] == ' ') {
        left++;
      }
      while (right > left && value[right - 1] == ' ') {
        right--;
      }
      final offset = start + line.start;
      row.add(
        TableCellSource(
          SourceRange(offset + left, offset + right),
          value.substring(left, right).replaceAll(r'\|', '|'),
        ),
      );
    }
    if (row.isNotEmpty) rows.add(row);
  }
  return rows;
}

class MarkdownTableEditor extends StatefulWidget {
  const MarkdownTableEditor({
    super.key,
    required this.controller,
    required this.start,
    required this.end,
    required this.style,
  });
  final MarkdownEditorController controller;
  final int start, end;
  final TextStyle style;
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

  int _sourceOffset(String text, int offset) => text
      .substring(0, offset.clamp(0, text.length))
      .replaceAll('|', r'\|')
      .length;

  void _changed(String key, int row, int column) {
    if (_syncing) return;
    final input = _inputs[key]!;
    if (input.value.composing.isValid && !input.value.composing.isCollapsed) {
      return;
    }
    final rows = _rows;
    if (row >= rows.length || column >= rows[row].length) return;
    final cell = rows[row][column];
    final encoded = input.text.replaceAll('|', r'\|');
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
            _sourceOffset(input.text, input.selection.baseOffset),
        cell.range.start +
            _sourceOffset(input.text, input.selection.extentOffset),
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
                            _cell(rows[row][col], row, col, columns),
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

  Widget _cell(TableCellSource cell, int row, int col, int columns) {
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
    return FocusTraversalOrder(
      order: NumericFocusOrder((row * columns + col).toDouble()),
      child: TextField(
        key: ValueKey('table-cell-$row-$col'),
        controller: input,
        focusNode: focus,
        style: widget.style.copyWith(
          fontWeight: row == 0 ? FontWeight.w600 : FontWeight.w400,
        ),
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
    );
  }
}
