import 'package:test/test.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

void main() {
  test('a nested loose list keeps paragraphs, fences, quotes and nested headings together', () {
    const list =
        '7. Parent\r\n\r\n'
        '   Second paragraph.\r\n\r\n'
        '   - Child\r\n'
        '     3. Grandchild\r\n\r\n'
        '   > Quote\r\n\r\n'
        '   ### Nested heading\r\n\r\n'
        '   ```md\r\n'
        '   # Not a document heading\r\n'
        '   ```\r\n\r\n'
        '8. Next parent\r\n\r\n';
    const source = '# Document\r\n\r\n${list}After.\r\n\r\n## End\r\n';
    final doc = MarkdownDocument.parse(source);
    expect(doc.blocks.map((b) => b.kind), [
      MarkdownBlockKind.heading,
      MarkdownBlockKind.list,
      MarkdownBlockKind.paragraph,
      MarkdownBlockKind.heading,
    ]);
    expect(doc.blocks[1].range.slice(source), list);
    expect(doc.blocks[1].line, 3);
    expect(doc.headings.map((h) => h.title), ['Document', 'End']);
    expect(doc.source, source);
  });

  test('list kinds, marker changes and horizontal rules follow CommonMark boundaries', () {
    const source = '- A\n  continuation\n- B\n\n* C\n\n1. D\n\n---\n\nAfter\n';
    final doc = MarkdownDocument.parse(source);
    expect(doc.blocks.map((b) => b.kind), [
      MarkdownBlockKind.list,
      MarkdownBlockKind.list,
      MarkdownBlockKind.list,
      MarkdownBlockKind.rule,
      MarkdownBlockKind.paragraph,
    ]);
    expect(
      doc.blocks.first.range.slice(source),
      '- A\n  continuation\n- B\n\n',
    );
    expect(doc.blocks[1].range.slice(source), '* C\n\n');
  });

  test('lazy continuation stays in a list but a non-1 ordered marker cannot interrupt a paragraph', () {
    const source =
        '- Parent\ncontinuation\n\nAfter\n9. literal continuation\n\n9. List\n';
    final doc = MarkdownDocument.parse(source);
    expect(doc.blocks.map((b) => b.kind), [
      MarkdownBlockKind.list,
      MarkdownBlockKind.paragraph,
      MarkdownBlockKind.list,
    ]);
    expect(doc.blocks.first.range.slice(source), '- Parent\ncontinuation\n\n');
    expect(
      doc.blocks[1].range.slice(source),
      'After\n9. literal continuation\n',
    );
  });

  test('source ranges and one-step history survive editing and undoing a nested item', () {
    const source = '- Parent\n  - Child\n    - Grandchild\n\nTail\n';
    final session = MarkdownSession(source);
    final offset = source.indexOf('Grandchild');
    session.patch(
      TextPatch(SourceRange(offset, offset + 10), 'Changed'),
      label: 'Nested item',
    );
    expect(session.document.blocks.first.kind, MarkdownBlockKind.list);
    expect(
      session.document.blocks.first.range.slice(session.text),
      contains('    - Changed'),
    );
    session.undo();
    expect(session.text, source);
    expect(session.canUndo, isFalse);
    session.redo();
    expect(session.text, contains('Changed'));
  });
}
