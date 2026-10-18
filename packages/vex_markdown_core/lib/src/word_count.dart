import 'package:markdown/markdown.dart' as md;

import 'document.dart';

/// Visible text, without Markdown markers, link destinations or HTML tags.
String markdownSummaryText(String source) {
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parseLines(source.split(RegExp(r'\r\n|\n|\r')));
  String text(md.Node node) {
    if (node is! md.Element) return node.textContent;
    if (node.tag == 'img') return node.attributes['alt'] ?? '';
    if (node.tag == 'br') return ' ';
    final separator =
        const {'table', 'thead', 'tbody', 'tr', 'ul', 'ol'}.contains(node.tag)
        ? ' '
        : '';
    return (node.children ?? const <md.Node>[]).map(text).join(separator);
  }

  return nodes.map(text).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// CJK letters count individually; other scripts count space-separated words.
/// Reuse unchanged blocks while typing, and do no work for caret-only changes.
final class MarkdownWordCounter {
  MarkdownDocument? _document;
  Map<String, int> _blocks = {};
  int _total = 0;
  static final _cjk = RegExp(
    r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
    unicode: true,
  );
  static final _word = RegExp(
    r"[\p{L}\p{N}][\p{L}\p{M}\p{N}]*(?:['\u2019_-][\p{L}\p{N}][\p{L}\p{M}\p{N}]*)*",
    unicode: true,
  );

  int count(MarkdownDocument document) {
    if (identical(document, _document)) return _total;
    final next = <String, int>{};
    var total = 0;
    for (final block in document.blocks) {
      final source = block.range.slice(document.source);
      final count = next[source] ??= _blocks[source] ?? _count(source);
      total += count;
    }
    _blocks = next;
    _document = document;
    return _total = total;
  }

  int _count(String source) {
    final text = markdownSummaryText(source);
    return _cjk.allMatches(text).length +
        _word.allMatches(text.replaceAll(_cjk, ' ')).length;
  }
}
