import 'package:test/test.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

void main() {
  test('formula blocks preserve blank lines, CRLF and section ranges', () {
    const source =
        '# Before\r\n\r\n\$\$\r\nx = 1\r\n\r\n# not a heading\r\n\$\$\r\n\r\n# After';
    final document = MarkdownDocument.parse(source);
    expect(document.headings.map((h) => h.title), ['Before', 'After']);
    final formula = document.blocks.singleWhere(
      (b) => b.kind == MarkdownBlockKind.math,
    );
    expect(
      formula.range.slice(source),
      '\$\$\r\nx = 1\r\n\r\n# not a heading\r\n\$\$\r\n',
    );
    expect(
      document.headings.first.body.slice(source),
      contains(formula.range.slice(source)),
    );
  });
  test(
    'bracket display and adjacent formulas stay separate from code and prose',
    () {
      const source =
          'before\n\\[a+b\\]\n\$\$c+d\$\$\nafter\n\n```tex\n\$\$x\$\$\n```';
      final document = MarkdownDocument.parse(source);
      expect(document.blocks.map((b) => b.kind), [
        MarkdownBlockKind.paragraph,
        MarkdownBlockKind.math,
        MarkdownBlockKind.math,
        MarkdownBlockKind.paragraph,
        MarkdownBlockKind.code,
      ]);
      expect(
        MarkdownDocument.parse('\$\$ unclosed\n# Still a heading').headings,
        hasLength(1),
      );
    },
  );
  test('inline display with following prose cannot absorb a later heading', () {
    final document = MarkdownDocument.parse(
      '\$\$x\$\$ trailing\n\n# Heading\n\n\$\$y\$\$',
    );
    expect(document.headings.single.title, 'Heading');
    expect(
      document.blocks.where((b) => b.kind == MarkdownBlockKind.math),
      hasLength(1),
    );
  });
}
