import 'package:vex_markdown_core/vex_markdown_core.dart';

enum MarkdownTableCommand {
  rowAbove,
  rowBelow,
  columnBefore,
  columnAfter,
  rowUp,
  rowDown,
  columnLeft,
  columnRight,
  alignLeft,
  alignCenter,
  alignRight,
  deleteRow,
  deleteColumn,
  copy,
  format,
  delete,
}

enum MarkdownTableAlignment { none, left, center, right }

/// A cell keeps its source range, including escaped pipes and code spans.
final class TableCellSource {
  const TableCellSource(this.range, this.text);
  final SourceRange range;
  final String text;
}

List<TableCellSource> _parseRow(String value, int offset) {
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
    row.add(
      TableCellSource(
        SourceRange(offset + left, offset + right),
        decodeTableCell(value.substring(left, right)),
      ),
    );
  }
  return row;
}

List<List<TableCellSource>> parseTableCells(String source, int start, int end) {
  final rows = <List<TableCellSource>>[];
  var index = 0;
  for (final line in RegExp(
    r'[^\r\n]+',
  ).allMatches(source.substring(start, end))) {
    if (index++ == 1 && RegExp(r'^\s*\|?\s*:?-{3,}').hasMatch(line[0]!)) {
      continue;
    }
    final row = _parseRow(line[0]!, start + line.start);
    if (row.isNotEmpty) rows.add(row);
  }
  return rows;
}

String encodeTableCell(String text) {
  final buffer = StringBuffer();
  var ticks = 0;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '`') {
      var count = 1;
      while (i + count < text.length && text[i + count] == '`') {
        count++;
      }
      ticks = ticks == count
          ? 0
          : ticks == 0
          ? count
          : ticks;
      buffer.write('`' * count);
      i += count - 1;
    } else if (text[i] == r'\' && ticks == 0) {
      var end = i + 1;
      while (end < text.length && text[end] == r'\') {
        end++;
      }
      if (end < text.length && text[end] == '|') {
        buffer.write('${r'\' * ((end - i) * 2 + 1)}|');
        i = end;
      } else {
        buffer.write(text.substring(i, end));
        i = end - 1;
      }
    } else {
      buffer.write(text[i] == '|' && ticks == 0 ? r'\|' : text[i]);
    }
  }
  return buffer.toString();
}

Iterable<(int, int, String)> _cellGlyphs(String raw) sync* {
  for (var i = 0; i < raw.length; i++) {
    if (raw[i] == r'\') {
      var end = i + 1;
      while (end < raw.length && raw[end] == r'\') {
        end++;
      }
      if (end < raw.length && raw[end] == '|' && (end - i).isOdd) {
        for (var at = i; at < end - 1; at += 2) {
          yield (at, at + 2, r'\');
        }
        yield (end - 1, end + 1, '|');
        i = end;
        continue;
      }
    }
    yield (i, i + 1, raw[i]);
  }
}

String decodeTableCell(String raw) =>
    _cellGlyphs(raw).map((glyph) => glyph.$3).join();

int tableCellSourceOffset(String raw, int displayedOffset) {
  var displayed = 0, offset = 0;
  for (final (_, end, _) in _cellGlyphs(raw)) {
    if (displayed >= displayedOffset) break;
    displayed++;
    offset = end;
  }
  return offset;
}

int tableCellDisplayOffset(String raw, int sourceOffset) =>
    _cellGlyphs(raw).takeWhile((glyph) => glyph.$1 < sourceOffset).length;

/// Source-preserving table model; formatting never decodes Markdown escapes.
final class MarkdownTable {
  MarkdownTable._(this.rows, this.alignments, this.newline, this.ending);
  final List<List<String>> rows;
  final List<MarkdownTableAlignment> alignments;
  final String newline, ending;
  int get columns => alignments.length;

  static MarkdownTable? parse(String source) {
    final lines = source.trimRight().split(RegExp(r'\r\n|\n|\r'));
    if (lines.length < 2) return null;
    List<String> rawCells(String line) =>
        _parseRow(line, 0).map((cell) => cell.range.slice(line)).toList();
    final header = rawCells(lines[0]), separators = rawCells(lines[1]);
    if (header.isEmpty ||
        header.length != separators.length ||
        separators.any((value) => !RegExp(r'^:?-{3,}:?$').hasMatch(value))) {
      return null;
    }
    final rows = [header, ...lines.skip(2).map(rawCells)];
    if (rows.any((row) => row.length > header.length)) return null;
    for (final row in rows) {
      while (row.length < header.length) {
        row.add('');
      }
    }
    final newline = source.contains('\r\n')
        ? '\r\n'
        : source.contains('\r')
        ? '\r'
        : '\n';
    return MarkdownTable._(
      rows,
      separators
          .map(
            (value) => value.startsWith(':')
                ? value.endsWith(':')
                      ? MarkdownTableAlignment.center
                      : MarkdownTableAlignment.left
                : value.endsWith(':')
                ? MarkdownTableAlignment.right
                : MarkdownTableAlignment.none,
          )
          .toList(),
      newline,
      source.endsWith(newline) ? newline : '',
    );
  }

  bool can(MarkdownTableCommand command, int row, int column) {
    if (row < 0 || row >= rows.length || column < 0 || column >= columns) {
      return false;
    }
    return switch (command) {
      MarkdownTableCommand.rowAbove ||
      MarkdownTableCommand.deleteRow => row > 0,
      MarkdownTableCommand.rowUp => row > 1,
      MarkdownTableCommand.rowDown => row > 0 && row < rows.length - 1,
      MarkdownTableCommand.columnLeft => column > 0,
      MarkdownTableCommand.columnRight => column < columns - 1,
      MarkdownTableCommand.deleteColumn => columns > 1,
      _ => true,
    };
  }

  /// Returns the new caret cell, keeping the header structurally fixed.
  (int, int) apply(MarkdownTableCommand command, int row, int column) {
    if (!can(command, row, column)) {
      throw StateError('Table command unavailable');
    }
    switch (command) {
      case MarkdownTableCommand.rowAbove || MarkdownTableCommand.rowBelow:
        row += command == MarkdownTableCommand.rowBelow ? 1 : 0;
        rows.insert(row, List.filled(columns, '', growable: true));
      case MarkdownTableCommand.deleteRow:
        rows.removeAt(row);
        row = row.clamp(0, rows.length - 1);
      case MarkdownTableCommand.rowUp || MarkdownTableCommand.rowDown:
        final next = row + (command == MarkdownTableCommand.rowUp ? -1 : 1);
        final previous = rows[row];
        rows[row] = rows[next];
        rows[next] = previous;
        row = next;
      case MarkdownTableCommand.columnBefore ||
          MarkdownTableCommand.columnAfter:
        column += command == MarkdownTableCommand.columnAfter ? 1 : 0;
        for (final cells in rows) {
          cells.insert(column, '');
        }
        alignments.insert(column, MarkdownTableAlignment.none);
      case MarkdownTableCommand.deleteColumn:
        for (final cells in rows) {
          cells.removeAt(column);
        }
        alignments.removeAt(column);
        column = column.clamp(0, columns - 1);
      case MarkdownTableCommand.columnLeft || MarkdownTableCommand.columnRight:
        final next =
            column + (command == MarkdownTableCommand.columnLeft ? -1 : 1);
        void swap<T>(List<T> cells) {
          final previous = cells[column];
          cells[column] = cells[next];
          cells[next] = previous;
        }
        for (final cells in rows) {
          swap(cells);
        }
        swap(alignments);
        column = next;
      case MarkdownTableCommand.alignLeft:
        alignments[column] = MarkdownTableAlignment.left;
      case MarkdownTableCommand.alignCenter:
        alignments[column] = MarkdownTableAlignment.center;
      case MarkdownTableCommand.alignRight:
        alignments[column] = MarkdownTableAlignment.right;
      case MarkdownTableCommand.copy ||
          MarkdownTableCommand.format ||
          MarkdownTableCommand.delete:
        break;
    }
    return (row, column);
  }

  String serialize() {
    final separators = alignments
        .map(
          (alignment) => switch (alignment) {
            MarkdownTableAlignment.left => ':---',
            MarkdownTableAlignment.center => ':---:',
            MarkdownTableAlignment.right => '---:',
            MarkdownTableAlignment.none => '---',
          },
        )
        .toList();
    final all = [rows.first, separators, ...rows.skip(1)];
    final widths = List.generate(
      columns,
      (column) => all.fold<int>(
        3,
        (max, cells) => cells[column].length > max ? cells[column].length : max,
      ),
    );
    return '${all.map((cells) => '| ${List.generate(columns, (column) => cells[column].padRight(widths[column])).join(' | ')} |').join(newline)}$ending';
  }
}
