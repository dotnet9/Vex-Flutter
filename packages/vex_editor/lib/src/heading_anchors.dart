import 'package:markdown/markdown.dart' as md;
import 'package:vex_markdown_core/vex_markdown_core.dart';

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
  static final _whitespace = RegExp(r'\s');
  static final _headingTag = RegExp(r'^h[1-6]$');

  String next(String text) {
    final base = text
        .trim()
        .toLowerCase()
        .replaceAll(_punctuation, '')
        .trim()
        .replaceAll(_whitespace, '-');
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
      if (_headingTag.hasMatch(node.tag)) {
        node.generatedId = null;
        node.attributes['id'] = next(_text(node, encodedHtml));
      }
    }
  }
}

/// 锚点结果按“文档实例 + 渲染偏好”缓存：TOC 在同一修订的多次重建间复用，
/// 避免每次 build 都对全文再跑一遍行解析。只保留最近几份，防止常驻泄漏。
final _anchorsCache = <String, Map<String, MarkdownHeading>>{};

final RegExp _anchorsLineBreakRe = RegExp(r'\r\n|\n|\r');

String _anchorsCacheKey(MarkdownDocument document, MarkdownPreferences p) =>
    '${identityHashCode(document)}|math:${p.math}|chem:${p.chemistry}'
    '|hl:${p.highlight}|sub:${p.subscript}|link:${p.autoLink}';

Map<String, MarkdownHeading> markdownHeadingAnchorsCached(
  MarkdownDocument document,
  MarkdownPreferences preferences,
) {
  final key = _anchorsCacheKey(document, preferences);
  final cached = _anchorsCache.remove(key);
  if (cached != null) {
    _anchorsCache[key] = cached;
    return cached;
  }
  final result = markdownHeadingAnchors(document, preferences: preferences);
  _anchorsCache[key] = result;
  while (_anchorsCache.length > 4) {
    _anchorsCache.remove(_anchorsCache.keys.first);
  }
  return result;
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
  parser.parseLines(document.source.split(_anchorsLineBreakRe));
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
