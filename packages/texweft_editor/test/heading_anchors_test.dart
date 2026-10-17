import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:texweft_editor/texweft_editor.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

void main() {
  test('heading anchors use rendered Unicode text and collision-safe IDs', () {
    const source =
        '# **中文** `标题` &amp; Café!\r\n\r\n'
        '## 重复\r\n## 重复\r\n## 重复-1\r\n## 重复\r\n\r\n'
        'Setext [引用][ref]\r\n---\r\n\r\n'
        '# ![图像](image.png)\r\n\r\n# 🎉\r\n\r\n'
        '```md\r\n# Not a heading\r\n```\r\n\r\n'
        '[ref]: https://example.com\r\n';
    final document = MarkdownDocument.parse(source);
    final anchors = markdownHeadingAnchors(document);
    expect(anchors.keys, [
      '中文-标题--café',
      '重复',
      '重复-1',
      '重复-1-1',
      '重复-2',
      'setext-引用',
      '图像',
      'section',
    ]);
    expect(anchors['重复-1']!.line, 4);
    expect(anchors.values.map((h) => h.id).toSet(), hasLength(8));
    final encoded = md.Document().parseLines(source.split('\r\n'));
    MarkdownHeadingIds().assign(encoded, encodedHtml: true);
    expect(
      encoded
          .whereType<md.Element>()
          .map((n) => n.attributes['id'])
          .whereType<String>(),
      anchors.keys,
    );
  });

  test('HTML fragment anchors share the document convention without re-parsing code', () {
    const source =
        '# **A_B** &amp; `x_y`\n\n[Go](#a_b--x_y)\n\n# **A_B** &amp; `x_y`\n';
    final fragment = markdownHtmlFragment(source, const MarkdownPreferences());
    expect(fragment, contains('<h1 id="a_b--x_y">'));
    expect(fragment, contains('<h1 id="a_b--x_y-1">'));
    expect(fragment, contains('href="#a_b--x_y"'));
    expect(fragment, contains('<code>x_y</code>'));
  });
}
