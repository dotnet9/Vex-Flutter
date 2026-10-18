import 'package:test/test.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

void main() {
  int count(String text) =>
      MarkdownWordCounter().count(MarkdownDocument.parse(text));

  test('count visible CJK letters and words, not punctuation or emoji', () {
    expect(count(''), 0);
    expect(count('Hello world!'), 2);
    expect(count('\u4f60\u597d world'), 3);
    expect(count('Hello\u4e16\u754c!'), 3);
    expect(count("don't cafe\u0301 re-entry"), 3);
    expect(count('\u{20000}\u{1f9d1}\u200d\u{1f4bb}'), 1);
  });

  test('Markdown markers and link destinations are not words', () {
    expect(count('# Title\n\n**Hello** [world](https://example.com/path)'), 3);
    expect(count('![A picture](./assets/a-picture.png)'), 2);
    expect(count('---\ntitle: Hidden metadata\n---\n\nVisible'), 1);
    expect(count('```dart\nhello world\n```'), 2);
    expect(count('| A | B |\n| --- | --- |\n| C | D |'), 4);
  });

  test('repeated blocks, edits and undo count whole document', () {
    final counter = MarkdownWordCounter();
    final original = MarkdownDocument.parse('Hello\n\nHello');
    expect(counter.count(original), 2);
    expect(counter.count(original), 2);
    expect(counter.count(MarkdownDocument.parse('Hello world\n\nHello')), 3);
    expect(counter.count(original), 2);
  });
}
