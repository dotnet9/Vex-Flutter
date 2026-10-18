part of 'selection_projection.dart';

final class MarkdownInlineToken {
  const MarkdownInlineToken(this.tag, this.range, this.content);
  final String tag;
  final SourceRange range, content;
}

/// Presentation metadata only; editing values and all offsets remain source
/// faithful. Block syntax, escapes and nested delimiters come from CommonMark.
List<MarkdownInlineToken> markdownInlineTokens(
  String raw,
  MarkdownPreferences preferences, {
  bool inlineOnly = false,
}) {
  final document = _PositionedDocument(raw, preferences);
  final nodes = inlineOnly
      ? document.parseInline(raw)
      : md.BlockParser(
          raw.split(RegExp(r'\r\n|\r|\n')).map(md.Line.new).toList(),
          document,
        ).parseLines();
  final tokens = <MarkdownInlineToken>[];
  SourceRange? extent(Iterable<SourceRange?> ranges) {
    final valid = ranges.whereType<SourceRange>().toList();
    if (valid.isEmpty) return null;
    return SourceRange(valid.first.start, valid.last.end);
  }

  SourceRange? visit(md.Node node) {
    if (node is md.UnparsedContent) {
      return extent(document.parseInline(node.textContent).map(visit));
    }
    if (document.positions[node] case final projection?) {
      final range = document.syntaxRanges[node]!;
      final content = extent(projection.characters);
      final child = node is md.Element ? node.children?.singleOrNull : null;
      if (child is md.Element) {
        if (content != null &&
            ['code', 'mark', 'sub', 'sup', 'a'].contains(child.tag)) {
          tokens.add(MarkdownInlineToken(child.tag, range, content));
        }
      }
      return range;
    }
    if (node is! md.Element) {
      return extent(document.locate(node.textContent).characters);
    }
    if (node.tag == 'pre') {
      document.skipFence();
      return extent(document.locate(node.textContent).characters);
    }
    final content = extent((node.children ?? <md.Node>[]).map(visit));
    if (content == null) return document.syntaxRanges[node];
    final label = document.labels[node];
    if (node.tag == 'a' && label != null) {
      final range = document.syntaxRanges[node]!;
      tokens.add(MarkdownInlineToken('a', range, label));
      return range;
    }
    final length = switch (node.tag) {
      'strong' || 'del' => 2,
      'em' => 1,
      _ => 0,
    };
    if (length > 0 &&
        content.start >= length &&
        content.end + length <= raw.length) {
      final open = raw.substring(content.start - length, content.start);
      final close = raw.substring(content.end, content.end + length);
      if (open == close &&
          ['*' * length, '_' * length, '~' * length].contains(open)) {
        final range = SourceRange(content.start - length, content.end + length);
        tokens.add(MarkdownInlineToken(node.tag, range, content));
        return range;
      }
    }
    return content;
  }

  for (final node in nodes) {
    visit(node);
  }
  return tokens;
}
