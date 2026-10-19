import 'dart:isolate';

import 'list_extent.dart';

/// An immutable range in Dart UTF-16 string offsets, matching Flutter selections.
final class SourceRange {
  const SourceRange(this.start, this.end) : assert(start >= 0 && end >= start);
  final int start;
  final int end;
  int get length => end - start;
  bool contains(int offset) => offset >= start && offset < end;
  String slice(String source) => source.substring(start, end);
}

enum MarkdownBlockKind {
  heading,
  paragraph,
  quote,
  list,
  code,
  math,
  table,
  rule,
}

/// A display block keeps the original source, including its line endings.
final class MarkdownBlock {
  const MarkdownBlock(this.kind, this.range, this.line);
  final MarkdownBlockKind kind;
  final SourceRange range;
  final int line;
}

final class MarkdownHeading {
  const MarkdownHeading({
    required this.id,
    required this.title,
    required this.level,
    required this.line,
    required this.header,
    required this.titleRange,
    required this.body,
    required this.section,
    required this.parentId,
  });
  final String id;
  final String title;
  final int level;
  final int line;
  final SourceRange header;
  final SourceRange titleRange;
  final SourceRange body;
  final SourceRange section;
  final String? parentId;
}

final class _Line {
  const _Line(this.text, this.start, this.end, this.number);
  final String text;
  final int start;
  final int end;
  final int number;
}

/// Markdown source is authoritative. Parsed structures never rewrite it.
final class MarkdownDocument {
  // 解析热路径的正则全部静态化：每键全量解析时避免每行重新编译。
  static final RegExp _lineBreakRe = RegExp(r'[^\r\n]*(?:\r\n|\n|\r|$)');
  static final RegExp _fenceRe = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
  static final RegExp _mathOpenRe = RegExp(r'^ {0,3}(\$\$|\\\[)');
  static final RegExp _atxRe = RegExp(
    r'^ {0,3}(#{1,6})(?:[ \t]+(.*?)|[ \t]*)$',
  );
  static final RegExp _atxClosingRe = RegExp(r'[ \t]+#+[ \t]*$');
  static final RegExp _setextRe = RegExp(r'^ {0,3}(=+|-+)[ \t]*$');
  static final RegExp _setextInterruptRe = RegExp(
    r'^ {0,3}([>\-*+]|\d+[.)])\s',
  );
  static final RegExp _quoteRe = RegExp(r'^ {0,3}>');
  static final RegExp _ruleRe = RegExp(
    r'^ {0,3}(?:\*\s*){3,}$|^ {0,3}(?:-\s*){3,}$|^ {0,3}(?:_\s*){3,}$',
  );
  static final RegExp _tableDelimRe = RegExp(r'^\s*\|?\s*:?-{3,}');

  MarkdownDocument._(this.source, this.headings, this.blocks, this.lineStarts);

  /// Keep small files cheap; move large initial parses off the UI isolate.
  static Future<MarkdownDocument> parseAsync(String source) async {
    if (source.length < 256 * 1024) return MarkdownDocument.parse(source);
    return Isolate.run(() => MarkdownDocument.parse(source));
  }

  factory MarkdownDocument.parse(String source) {
    final lines = <_Line>[];
    var offset = 0;
    for (final match in _lineBreakRe.allMatches(source)) {
      if (match.start == source.length) break;
      final raw = match.group(0)!;
      // 手工去行尾换行，替代逐行正则替换。
      var text = raw;
      if (text.endsWith('\r\n')) {
        text = text.substring(0, text.length - 2);
      } else if (text.endsWith('\n') || text.endsWith('\r')) {
        text = text.substring(0, text.length - 1);
      }
      lines.add(_Line(text, offset, offset + raw.length, lines.length + 1));
      offset += raw.length;
    }
    final specs =
        <
          ({
            String title,
            int level,
            _Line line,
            int end,
            SourceRange titleRange,
          })
        >[];
    final blocks = <MarkdownBlock>[];
    final lists = ListExtentParser(lines.map((line) => line.text).toList());
    String? fence;
    var fenceLength = 0;
    var codeStart = 0;
    var codeLine = 1;
    var frontmatter =
        lines.isNotEmpty &&
        lines.first.text == '---' &&
        lines.skip(1).any((line) => line.text == '---' || line.text == '...');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = line.text;
      if (frontmatter) {
        if (i > 0 && (text == '---' || text == '...')) frontmatter = false;
        continue;
      }
      final marker = _fenceRe.firstMatch(text);
      if (fence != null) {
        if (marker != null &&
            marker[1]![0] == fence &&
            marker[1]!.length >= fenceLength &&
            marker[2]!.trim().isEmpty) {
          blocks.add(
            MarkdownBlock(
              MarkdownBlockKind.code,
              SourceRange(codeStart, line.end),
              codeLine,
            ),
          );
          fence = null;
        }
        continue;
      }
      if (marker != null &&
          !(marker[1]![0] == '`' && marker[2]!.contains('`'))) {
        fence = marker[1]![0];
        fenceLength = marker[1]!.length;
        codeStart = line.start;
        codeLine = line.number;
        continue;
      }
      if (text.trim().isEmpty) continue;
      final mathOpen = _mathOpenRe.firstMatch(text);
      if (mathOpen != null) {
        final close = mathOpen[1] == r'$$' ? r'$$' : r'\]';
        var size = 0;
        int? last;
        for (var j = i; j < lines.length && j < i + 256; j++) {
          size += lines[j].text.length;
          if (size > 8192) break;
          final content = j == i
              ? lines[j].text.substring(mathOpen.end)
              : lines[j].text;
          var position = content.indexOf(close);
          while (position >= 0) {
            var escapes = 0;
            for (var k = position - 1; k >= 0 && content[k] == r'\'; k--) {
              escapes++;
            }
            if (escapes.isEven) break;
            position = content.indexOf(close, position + close.length);
          }
          if (position >= 0) {
            if (content.substring(position + close.length).trim().isEmpty) {
              last = j;
            }
            break;
          }
        }
        if (last != null) {
          blocks.add(
            MarkdownBlock(
              MarkdownBlockKind.math,
              SourceRange(line.start, lines[last].end),
              line.number,
            ),
          );
          i = last;
          continue;
        }
      }
      final listEnd = lists.endOfList(
        i,
        interruptsParagraph:
            blocks.isNotEmpty &&
            blocks.last.kind == MarkdownBlockKind.paragraph &&
            blocks.last.range.end == line.start,
      );
      if (listEnd != null) {
        blocks.add(
          MarkdownBlock(
            MarkdownBlockKind.list,
            SourceRange(line.start, lines[listEnd - 1].end),
            line.number,
          ),
        );
        i = listEnd - 1;
        continue;
      }
      final atx = _atxRe.firstMatch(text);
      var isHeading = false;
      if (atx != null) {
        final original = atx[2] ?? '';
        final title = original.replaceFirst(_atxClosingRe, '').trimRight();
        final titleStart = title.isEmpty ? text.length : text.indexOf(original);
        specs.add((
          title: title,
          level: atx[1]!.length,
          line: line,
          end: line.end,
          titleRange: SourceRange(
            line.start + titleStart,
            line.start + titleStart + title.length,
          ),
        ));
        isHeading = true;
      } else if (!text.startsWith('    ') &&
          i + 1 < lines.length &&
          _setextRe.hasMatch(lines[i + 1].text) &&
          !_setextInterruptRe.hasMatch(text)) {
        final title = text.trim();
        specs.add((
          title: title,
          level: lines[i + 1].text.trimLeft().startsWith('=') ? 1 : 2,
          line: line,
          end: lines[i + 1].end,
          titleRange: SourceRange(
            line.start + text.indexOf(title),
            line.start + text.indexOf(title) + title.length,
          ),
        ));
        isHeading = true;
        i++;
      }
      final kind = isHeading
          ? MarkdownBlockKind.heading
          : _quoteRe.hasMatch(text)
          ? MarkdownBlockKind.quote
          : _ruleRe.hasMatch(text)
          ? MarkdownBlockKind.rule
          : text.contains('|') &&
                ((i + 1 < lines.length &&
                        _tableDelimRe.hasMatch(lines[i + 1].text)) ||
                    (blocks.isNotEmpty &&
                        blocks.last.kind == MarkdownBlockKind.table &&
                        blocks.last.range.end == line.start))
          ? MarkdownBlockKind.table
          : MarkdownBlockKind.paragraph;
      final end = lines[i].end;
      if (blocks.isNotEmpty &&
          !isHeading &&
          kind != MarkdownBlockKind.rule &&
          blocks.last.kind == kind &&
          blocks.last.range.end == line.start) {
        final previous = blocks.removeLast();
        blocks.add(
          MarkdownBlock(
            kind,
            SourceRange(previous.range.start, end),
            previous.line,
          ),
        );
      } else {
        blocks.add(
          MarkdownBlock(kind, SourceRange(line.start, end), line.number),
        );
      }
    }
    if (fence != null) {
      blocks.add(
        MarkdownBlock(
          MarkdownBlockKind.code,
          SourceRange(codeStart, source.length),
          codeLine,
        ),
      );
    }
    final headings = <MarkdownHeading>[];
    final stack = <MarkdownHeading>[];
    final occurrences = <String, int>{};
    // 逆序单调栈预计算每个标题的“下一个同级或更高级标题”起点，避免 O(H²) 扫描。
    final sectionStarts = List<int>.filled(specs.length, source.length);
    final pending = <int>[];
    for (var i = specs.length - 1; i >= 0; i--) {
      while (pending.isNotEmpty && specs[pending.last].level > specs[i].level) {
        pending.removeLast();
      }
      sectionStarts[i] = pending.isEmpty
          ? source.length
          : specs[pending.last].line.start;
      pending.add(i);
    }
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      while (stack.isNotEmpty && stack.last.level >= spec.level) {
        stack.removeLast();
      }
      final identity = '${spec.level}:${spec.title}';
      final occurrence = occurrences.update(
        identity,
        (v) => v + 1,
        ifAbsent: () => 0,
      );
      final heading = MarkdownHeading(
        id: '$identity:$occurrence',
        title: spec.title,
        level: spec.level,
        line: spec.line.number,
        header: SourceRange(spec.line.start, spec.end),
        titleRange: spec.titleRange,
        body: SourceRange(
          spec.end,
          i + 1 < specs.length ? specs[i + 1].line.start : source.length,
        ),
        section: SourceRange(spec.line.start, sectionStarts[i]),
        parentId: stack.lastOrNull?.id,
      );
      headings.add(heading);
      stack.add(heading);
    }
    return MarkdownDocument._(
      source,
      List.unmodifiable(headings),
      List.unmodifiable(blocks),
      List.unmodifiable([0, ...lines.skip(1).map((l) => l.start)]),
    );
  }

  final String source;
  final List<MarkdownHeading> headings;
  final List<MarkdownBlock> blocks;
  final List<int> lineStarts;
  String get newline => source.contains('\r\n') ? '\r\n' : '\n';
  MarkdownHeading? heading(String id) =>
      headings.where((h) => h.id == id).firstOrNull;
  ({int line, int column}) position(int offset) {
    final safe = offset.clamp(0, source.length);
    var low = 0, high = lineStarts.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (lineStarts[middle] <= safe) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return (line: low + 1, column: safe - lineStarts[low] + 1);
  }
}
