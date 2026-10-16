/// An immutable range in Dart UTF-16 string offsets, matching Flutter selections.
final class SourceRange {
  const SourceRange(this.start, this.end) : assert(start >= 0 && end >= start);
  final int start;
  final int end;
  int get length => end - start;
  bool contains(int offset) => offset >= start && offset < end;
  String slice(String source) => source.substring(start, end);
}

enum MarkdownBlockKind { heading, paragraph, quote, list, code, table, rule }

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
  MarkdownDocument._(this.source, this.headings, this.blocks, this.lineStarts);

  factory MarkdownDocument.parse(String source) {
    final lines = <_Line>[];
    var offset = 0;
    for (final match in RegExp(
      r'[^\r\n]*(?:\r\n|\n|\r|$)',
    ).allMatches(source)) {
      if (match.start == source.length) break;
      final raw = match.group(0)!;
      lines.add(
        _Line(
          raw.replaceFirst(RegExp(r'[\r\n]+$'), ''),
          offset,
          offset + raw.length,
          lines.length + 1,
        ),
      );
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
      final marker = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$').firstMatch(text);
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
      final atx = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+(.*?)|[ \t]*)$')
          .firstMatch(text);
      var isHeading = false;
      if (atx != null) {
        final original = atx[2] ?? '';
        final title = original
            .replaceFirst(RegExp(r'[ \t]+#+[ \t]*$'), '')
            .trimRight();
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
          RegExp(r'^ {0,3}(=+|-+)[ \t]*$').hasMatch(lines[i + 1].text) &&
          !RegExp(r'^ {0,3}([>\-*+]|\d+[.)])\s').hasMatch(text)) {
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
          : RegExp(r'^ {0,3}>').hasMatch(text)
          ? MarkdownBlockKind.quote
          : RegExp(r'^ {0,3}(?:[-+*]|\d+[.)])\s').hasMatch(text)
          ? MarkdownBlockKind.list
          : RegExp(
              r'^ {0,3}(?:\*\s*){3,}$|^ {0,3}(?:-\s*){3,}$|^ {0,3}(?:_\s*){3,}$',
            ).hasMatch(text)
          ? MarkdownBlockKind.rule
          : text.contains('|')
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
      final next = specs
          .skip(i + 1)
          .where((s) => s.level <= spec.level)
          .firstOrNull;
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
        section: SourceRange(
          spec.line.start,
          next?.line.start ?? source.length,
        ),
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
