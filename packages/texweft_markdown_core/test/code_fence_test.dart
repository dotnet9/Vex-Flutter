import 'package:test/test.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

void main() {
  test('editing preserves CRLF, fence indentation and info metadata', () {
    const raw = '  ~~~~ dart title="示例"\r\n第一行\r\n第二行\r\n  ~~~~\r\n';
    final block = MarkdownCodeFence.parse(raw)!;
    expect(block.language, 'dart');
    expect(block.code, '第一行\r\n第二行');
    expect(block.replace(code: block.code, language: block.language), raw);
    expect(block.replace(code: '第一行\n第二行', language: block.language), raw);
    expect(
      block.replace(code: '第一行\n新内容', language: 'c++'),
      '  ~~~~ c++ title="示例"\r\n第一行\r\n新内容\r\n  ~~~~\r\n',
    );
  });

  test('empty and unclosed fences remain editable without adding a closer', () {
    final empty = MarkdownCodeFence.parse('```\n```')!;
    expect(empty.code, '');
    expect(empty.replace(code: 'hello', language: ''), '```\nhello\n```');
    final unclosed = MarkdownCodeFence.parse('```text\nhello\n')!;
    expect(unclosed.replace(code: 'bye', language: 'dart'), '```dart\nbye\n');
  });

  test('literal closing fences in edited code cannot break the document', () {
    final block = MarkdownCodeFence.parse('```markdown\n示例\n```\n')!;
    final result = block.replace(
      code: '```\n# 代码内标题\n```',
      language: 'markdown',
    );
    expect(result, '````markdown\n```\n# 代码内标题\n```\n````\n');
    expect(MarkdownDocument.parse(result).headings, isEmpty);
    expect(MarkdownCodeFence.parse(result)!.code, '```\n# 代码内标题\n```');
  });
}
