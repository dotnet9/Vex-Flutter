import 'package:vex_markdown_core/vex_markdown_core.dart';

import 'controller.dart';
import 'table_model.dart';

final class MarkdownTableTarget {
  MarkdownTableTarget._(
    this.controller,
    this.source,
    this.revision,
    this.block,
    this.table,
    this.row,
    this.column,
  );
  final MarkdownEditorController controller;
  final String source;
  final int revision, row, column;
  final MarkdownBlock block;
  final MarkdownTable table;
  bool get isCurrent =>
      controller.session.revision == revision && controller.text == source;
  bool can(MarkdownTableCommand command) =>
      isCurrent && table.can(command, row, column);
}

extension MarkdownTableEditing on MarkdownEditorController {
  MarkdownTableTarget? tableTarget({int? offset, int? row, int? column}) {
    final at = offset ?? (selection.isValid ? selection.start : -1);
    final block = document.blocks
        .where(
          (block) =>
              block.kind == MarkdownBlockKind.table && block.range.contains(at),
        )
        .firstOrNull;
    if (block == null) return null;
    final raw = block.range.slice(text), table = MarkdownTable.parse(raw);
    if (table == null) return null;
    final cells = parseTableCells(text, block.range.start, block.range.end);
    var activeRow = 0, activeColumn = 0;
    for (var r = 0; r < cells.length; r++) {
      if (cells[r].first.range.start <= at) activeRow = r;
      for (var c = 0; c < cells[r].length; c++) {
        if (at >= cells[r][c].range.start && at <= cells[r][c].range.end) {
          activeRow = r;
          activeColumn = c;
        }
      }
    }
    return MarkdownTableTarget._(
      this,
      text,
      session.revision,
      block,
      table,
      (row ?? activeRow).clamp(0, table.rows.length - 1),
      (column ?? activeColumn).clamp(0, table.columns - 1),
    );
  }

  void editTable(MarkdownTableTarget target, MarkdownTableCommand command) {
    if (!identical(target.controller, this) || !target.isCurrent) {
      throw StateError('Document changed');
    }
    if (!target.can(command) || command == MarkdownTableCommand.copy) return;
    // Work on a fresh model so a menu snapshot cannot change after construction.
    final table = MarkdownTable.parse(target.block.range.slice(text))!;
    final (row, column) = table.apply(command, target.row, target.column);
    final replacement = command == MarkdownTableCommand.delete
        ? ''
        : table.serialize();
    final start = target.block.range.start;
    session.patch(TextPatch(target.block.range, replacement), label: '编辑表格结构');
    if (replacement.isEmpty) {
      select(start);
      return;
    }
    final cells = parseTableCells(text, start, start + replacement.length);
    final cell = cells[row][column];
    select(cell.range.start, cell.range.end);
  }
}
