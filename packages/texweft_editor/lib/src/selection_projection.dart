import 'package:markdown/markdown.dart' as md;
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'markdown_preferences.dart';
import 'markdown_syntax.dart';
import 'table_model.dart';

part 'inline_presentation.dart';

/// Coordinates for rendered text. CommonMark still owns syntax recognition;
/// lightweight wrapper nodes retain positions while it resolves delimiters.
final class MarkdownSelectionProjection {
  MarkdownSelectionProjection(this.text, this.characters);
  final String text;
  final List<SourceRange> characters;

  factory MarkdownSelectionProjection.literal(String raw, {int start = 0}) {
    final text = StringBuffer(), ranges = <SourceRange>[];
    for (var i = 0; i < raw.length; i++) {
      final end = raw[i] == '\r' && i + 1 < raw.length && raw[i + 1] == '\n'
          ? i + 2
          : i + 1;
      text.write(raw[i] == '\r' ? '\n' : raw[i]);
      ranges.add(SourceRange(start + i, start + end));
      i = end - 1;
    }
    return MarkdownSelectionProjection(text.toString(), ranges);
  }

  factory MarkdownSelectionProjection.block(
    String raw,
    MarkdownBlockKind kind,
    MarkdownPreferences preferences,
  ) {
    if (kind == MarkdownBlockKind.table) {
      final text = StringBuffer(), ranges = <SourceRange>[];
      for (final row in parseTableCells(raw, 0, raw.length)) {
        for (final cell in row) {
          final projection = MarkdownSelectionProjection.block(
            cell.text,
            MarkdownBlockKind.paragraph,
            preferences,
          );
          final encoded = cell.range.slice(raw);
          text.write(projection.text);
          ranges.addAll([
            for (final char in projection.characters)
              SourceRange(
                cell.range.start + tableCellSourceOffset(encoded, char.start),
                cell.range.start + tableCellSourceOffset(encoded, char.end),
              ),
          ]);
        }
      }
      return MarkdownSelectionProjection(text.toString(), ranges);
    }
    if (kind == MarkdownBlockKind.code) {
      final fence = MarkdownCodeFence.parse(raw);
      if (fence != null) {
        return MarkdownSelectionProjection.literal(
          fence.code,
          start: fence.bodyOffset(),
        );
      }
    }
    final document = _PositionedDocument(raw, preferences);
    final nodes = md.BlockParser(
      raw.split(RegExp(r'\r\n|\r|\n')).map(md.Line.new).toList(),
      document,
    ).parseLines();
    final text = StringBuffer(), ranges = <SourceRange>[];
    void collect(md.Node node) {
      if (node is md.UnparsedContent) {
        for (final inline in document.parseInline(node.textContent)) {
          collect(inline);
        }
      } else if (document.positions[node] case final projection?) {
        text.write(projection.text);
        ranges.addAll(projection.characters);
      } else if (node is md.Element) {
        if (['img', 'input', 'vex-math', 'vex-math-block'].contains(node.tag)) {
          return;
        }
        if (node.tag == 'pre') {
          document.skipFence();
          final projection = document.locate(node.textContent);
          text.write(projection.text);
          ranges.addAll(projection.characters);
          return;
        }
        for (final child in node.children ?? <md.Node>[]) {
          collect(child);
        }
      } else if (node.textContent.isNotEmpty) {
        final projection = document.locate(node.textContent);
        text.write(projection.text);
        ranges.addAll(projection.characters);
      }
    }

    for (final node in nodes) {
      collect(node);
    }
    return MarkdownSelectionProjection(text.toString(), ranges);
  }

  int sourceOffset(int displayOffset) {
    if (characters.isEmpty) return 0;
    return displayOffset >= characters.length
        ? characters.last.end
        : characters[displayOffset.clamp(0, characters.length - 1)].start;
  }
}

class _PositionedDocument extends md.Document {
  _PositionedDocument(this.raw, MarkdownPreferences preferences)
    : super(
        extensionSet: MarkdownSyntax.extensions(preferences),
        inlineSyntaxes: MarkdownSyntax.inlines(preferences),
        blockSyntaxes: MarkdownSyntax.blocks(preferences),
        encodeHtml: false,
      );
  final String raw;
  final positions = Map<md.Node, MarkdownSelectionProjection>.identity();
  final syntaxRanges = Map<md.Node, SourceRange>.identity();
  final labels = Map<md.Node, SourceRange>.identity();
  late final _positionedSyntaxes = <md.InlineSyntax>[
    _ProjectionLink(),
    ...super.inlineSyntaxes,
  ];
  @override
  Iterable<md.InlineSyntax> get inlineSyntaxes => _positionedSyntaxes;
  int _cursor = 0;

  void skipFence() {
    final opening = RegExp(r'[\r\n \t]*(?:`{3,}|~{3,})[^\r\n]*(?:\r\n|\r|\n)')
        .matchAsPrefix(raw, _cursor);
    if (opening != null) _cursor = opening.end;
  }

  MarkdownSelectionProjection locate(String text) {
    final ranges = <SourceRange>[];
    final lines = text.split('\n');
    for (var index = 0; index < lines.length; index++) {
      if (index > 0) {
        final next = raw.indexOf(RegExp(r'\r\n|\r|\n'), _cursor);
        final ending = next < 0
            ? _cursor
            : next + (raw.startsWith('\r\n', next) ? 2 : 1);
        ranges.add(SourceRange(next < 0 ? _cursor : next, ending));
        _cursor = ending;
      }
      final line = lines[index];
      var at = raw.indexOf(line, _cursor);
      if (line.isNotEmpty && at >= 0) {
        final lineEnd = raw.indexOf(RegExp(r'\r|\n'), at);
        final end = lineEnd < 0 ? raw.length : lineEnd;
        final candidate = raw.substring(_cursor, end);
        // BlockParser removes structural prefixes, never repeated body text.
        final trimmed = candidate.replaceFirst(RegExp(r'[ \t]+#+[ \t]*$'), '');
        if (trimmed.endsWith(line)) at = _cursor + trimmed.length - line.length;
      }
      if (at < 0) at = _cursor;
      for (var i = 0; i < line.length; i++) {
        ranges.add(
          SourceRange(
            (at + i).clamp(0, raw.length),
            (at + i + 1).clamp(0, raw.length),
          ),
        );
      }
      _cursor = (at + line.length).clamp(0, raw.length);
    }
    return MarkdownSelectionProjection(text, ranges);
  }

  @override
  List<md.Node> parseInline(String text) {
    final input = locate(text);
    final parser = _PositionedInlineParser(text, this);
    final nodes = parser.parse();
    for (final entry in parser.ranges.entries) {
      final node = entry.key, range = entry.value;
      syntaxRanges[node] = SourceRange(
        input.characters[range.start].start,
        input.characters[range.end - 1].end,
      );
      final visible = _visible(node);
      final local = _tokenProjection(
        text.substring(range.start, range.end),
        visible,
        literal: parser.literals.contains(node),
      );
      positions[node] = MarkdownSelectionProjection(visible, [
        for (final char in local.characters)
          SourceRange(
            input.characters[range.start + char.start].start,
            input.characters[range.start + char.end - 1].end,
          ),
      ]);
    }
    for (final entry in parser.links.entries) {
      final (range, label) = entry.value;
      syntaxRanges[entry.key] = SourceRange(
        input.characters[range.start].start,
        input.characters[range.end - 1].end,
      );
      labels[entry.key] = SourceRange(
        input.characters[label.start].start,
        input.characters[label.end - 1].end,
      );
    }
    return nodes;
  }
}

String _visible(md.Node node) {
  if (node is! md.Element) return node.textContent;
  if (['img', 'vex-math', 'vex-math-block'].contains(node.tag)) return '';
  if (node.tag == 'br') return '\n';
  return node.children?.map(_visible).join() ?? '';
}

MarkdownSelectionProjection _tokenProjection(
  String raw,
  String text, {
  required bool literal,
}) {
  if (literal || raw == text) {
    return MarkdownSelectionProjection.literal(raw);
  }
  if (text.isEmpty) return MarkdownSelectionProjection('', []);
  if (raw.startsWith('`')) {
    final marker = RegExp(r'^`+').firstMatch(raw)!.end;
    var left = marker, right = raw.length - marker;
    var body = raw.substring(left, right).replaceAll('\n', ' ');
    if (body.trim().isNotEmpty && body.startsWith(' ') && body.endsWith(' ')) {
      left++;
      right--;
      body = body.substring(1, body.length - 1);
    }
    if (body == text) {
      return MarkdownSelectionProjection(text, [
        for (var i = left; i < right; i++) SourceRange(i, i + 1),
      ]);
    }
  }
  final exact = raw.indexOf(text);
  if (exact >= 0 && !(raw.startsWith('&') && raw.endsWith(';'))) {
    return MarkdownSelectionProjection.literal(text, start: exact);
  }
  // Entity decoding and normalized inline-code whitespace can represent more
  // than one source unit. Keep their full source extent instead of splitting it.
  return MarkdownSelectionProjection(text, [
    for (var i = 0; i < text.length; i++) SourceRange(0, raw.length),
  ]);
}

class _PositionedInlineParser extends md.InlineParser {
  _PositionedInlineParser(super.source, super.document);
  final ranges = Map<md.Node, SourceRange>.identity();
  final literals = Set<md.Node>.identity();
  final links = Map<md.Node, (SourceRange, SourceRange)>.identity();
  final _delimiters = <(md.Delimiter, int, int)>[];
  final _pending = <md.Node>[];

  @override
  void writeText() {
    if (pos == start) return;
    final node = md.Element('vex-source-position', [
      md.Text(source.substring(start, pos)),
    ]);
    literals.add(node);
    ranges[node] = SourceRange(start, pos);
    super.addNode(node);
    start = pos;
  }

  @override
  void pushDelimiter(md.Delimiter delimiter) {
    _delimiters.add((delimiter, pos, delimiter.length));
    super.pushDelimiter(delimiter);
  }

  @override
  void addNode(md.Node node) {
    if (_delimiters.any((entry) => identical(entry.$1.node, node))) {
      super.addNode(node);
      return;
    }
    final wrapper = md.Element('vex-source-position', [node]);
    ranges[wrapper] = SourceRange(pos, (pos + 1).clamp(0, source.length));
    _pending.add(wrapper);
    super.addNode(wrapper);
  }

  @override
  void consume(int length) {
    for (final node in _pending) {
      ranges[node] = SourceRange(ranges[node]!.start, pos + length);
    }
    _pending.clear();
    super.consume(length);
  }

  @override
  void advanceBy(int length) {
    if (_pending.isNotEmpty) {
      for (final node in _pending) {
        ranges[node] = SourceRange(ranges[node]!.start, pos + length);
      }
      _pending.clear();
    }
    super.advanceBy(length);
  }

  @override
  List<md.Node> parse() {
    final nodes = super.parse();
    for (final (delimiter, at, length) in _delimiters) {
      final remaining = delimiter.node.text.length;
      ranges[delimiter.node] = SourceRange(
        at + length - remaining,
        at + length,
      );
      literals.add(delimiter.node);
    }
    final leaves = <md.Node>[];
    void visit(md.Node node) {
      if (ranges.containsKey(node) || node is! md.Element) {
        leaves.add(node);
      } else {
        for (final child in node.children ?? <md.Node>[]) {
          visit(child);
        }
      }
    }

    for (final node in nodes) {
      visit(node);
    }
    var cursor = 0;
    for (var i = 0; i < leaves.length; i++) {
      final node = leaves[i];
      if (ranges[node] case final range?) {
        cursor = range.end;
      } else if (node is md.Text && node.text.isNotEmpty) {
        final next =
            leaves
                .skip(i + 1)
                .map((n) => ranges[n])
                .whereType<SourceRange>()
                .firstOrNull
                ?.start ??
            source.length;
        final at = source.lastIndexOf(
          node.text,
          (next - node.text.length).clamp(0, source.length),
        );
        if (at >= cursor) {
          ranges[node] = SourceRange(at, at + node.text.length);
          literals.add(node);
          cursor = at + node.text.length;
        }
      }
    }
    return nodes;
  }
}

class _ProjectionLink extends md.LinkSyntax {
  @override
  Iterable<md.Node>? close(
    md.InlineParser parser,
    covariant md.SimpleDelimiter opener,
    md.Delimiter? closer, {
    String? tag,
    required List<md.Node> Function() getChildren,
  }) {
    final labelEnd = parser.pos;
    final result = super.close(
      parser,
      opener,
      closer,
      tag: tag,
      getChildren: getChildren,
    );
    if (parser is _PositionedInlineParser &&
        result != null &&
        labelEnd > opener.endPos) {
      for (final node in result) {
        parser.links[node] = (
          SourceRange(opener.endPos - opener.length, parser.pos + 1),
          SourceRange(opener.endPos, labelEnd),
        );
      }
    }
    return result;
  }
}
