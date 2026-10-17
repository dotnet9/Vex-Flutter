import 'package:markdown/markdown.dart' as md;
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'markdown_preferences.dart';
import 'markdown_syntax.dart';

/// Heading IDs use rendered Unicode text, independently of structural node IDs.
final class MarkdownHeadingIds {
  final _used = <String>{};
  final _decoder = md.Document(
    encodeHtml: false,
    withDefaultInlineSyntaxes: false,
    inlineSyntaxes: [md.DecodeHtmlSyntax()],
  );
  static final _punctuation = RegExp(r'[^\p{L}\p{M}\p{N}_\-\s]', unicode: true);

  String next(String text) {
    final base = text
        .trim()
        .toLowerCase()
        .replaceAll(_punctuation, '')
        .trim()
        .replaceAll(RegExp(r'\s'), '-');
    final slug = base.isEmpty ? 'section' : base;
    var candidate = slug, suffix = 0;
    while (!_used.add(candidate)) {
      candidate = '$slug-${++suffix}';
    }
    return candidate;
  }

  String _text(md.Node node, bool encodedHtml) {
    final text = node is md.Element
        ? node.tag == 'img'
              ? node.attributes['alt'] ?? ''
              : (node.children ?? []).map((n) => _text(n, encodedHtml)).join()
        : node.textContent;
    if ((node is md.Element && node.tag != 'img') || !encodedHtml) return text;
    return _decoder.parseInline(text).map((n) => n.textContent).join();
  }

  /// Assign before rendering HTML so links have the same IDs as the workspace.
  void assign(List<md.Node> nodes, {bool encodedHtml = false}) {
    for (final node in nodes) {
      if (node is! md.Element) continue;
      if (RegExp(r'^h[1-6]$').hasMatch(node.tag)) {
        node.generatedId = null;
        node.attributes['id'] = next(_text(node, encodedHtml));
      }
    }
  }
}

Map<String, MarkdownHeading> markdownHeadingAnchors(
  MarkdownDocument document, {
  MarkdownPreferences preferences = const MarkdownPreferences(),
}) {
  final parser = md.Document(
    extensionSet: MarkdownSyntax.extensions(preferences),
    blockSyntaxes: MarkdownSyntax.blocks(preferences),
    inlineSyntaxes: MarkdownSyntax.inlines(preferences),
    encodeHtml: false,
  );
  // Resolve reference-style links in heading text using this document's labels.
  parser.parseLines(document.source.split(RegExp(r'\r\n|\n|\r')));
  final ids = MarkdownHeadingIds();
  final result = <String, MarkdownHeading>{};
  for (final heading in document.headings) {
    final element = md.Element(
      'h${heading.level}',
      parser.parseInline(heading.title),
    );
    ids.assign([element]);
    result[element.attributes['id']!] = heading;
  }
  return result;
}
