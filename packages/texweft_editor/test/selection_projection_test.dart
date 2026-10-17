import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/src/markdown_preferences.dart';
import 'package:texweft_editor/src/selection_projection.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

void main() {
  void check(
    String raw,
    String visible,
    Map<String, String> fragments, {
    MarkdownBlockKind kind = MarkdownBlockKind.paragraph,
  }) {
    final projection = MarkdownSelectionProjection.block(
      raw,
      kind,
      const MarkdownPreferences(),
    );
    expect(projection.text, visible);
    expect(projection.characters.length, visible.length);
    for (final range in projection.characters) {
      expect(range.start, inInclusiveRange(0, raw.length));
      expect(range.end, inInclusiveRange(range.start, raw.length));
    }
    for (final entry in fragments.entries) {
      final at = visible.indexOf(entry.key);
      expect(at, greaterThanOrEqualTo(0));
      final start = projection.sourceOffset(at);
      final end = projection.characters[at + entry.key.length - 1].end;
      expect(raw.substring(start, end), entry.value, reason: entry.key);
    }
  }

  test('CommonMark delimiters retain exact source positions', () {
    check(
      '*_ literal [unclosed and **bold**',
      '*_ literal [unclosed and bold',
      {'*_': '*_', '[unclosed': '[unclosed', 'bold': 'bold'},
    );
    check('` a\r\nb ` tail', 'a b tail', {'a': 'a', 'b': 'b', 'tail': 'tail'});
    check(
      'Before **bold** and *italic* after.',
      'Before bold and italic after.',
      {
        'Before': 'Before',
        'bold': 'bold',
        'italic': 'italic',
        'after.': 'after.',
      },
    );
    check(
      '***nested*** and **repeat repeat** repeat.',
      'nested and repeat repeat repeat.',
      {'nested': 'nested', 'repeat repeat': 'repeat repeat'},
    );
    check(r'A \* literal &amp; `code` after.', 'A * literal & code after.', {
      '*': '*',
      '&': '&amp;',
      'code': 'code',
      'after.': 'after.',
    });
  });

  test('table cells retain escaped pipes and repeated source positions', () {
    check('| A | B |\r\n| --- | --- |\r\n| a\\|b | **bold** |', 'ABa|bbold', {
      'a|b': r'a\|b',
      'bold': 'bold',
    }, kind: MarkdownBlockKind.table);
  });

  test('link destinations and titles never become visible coordinates', () {
    check('[same](https://same/same "same") same **same**', 'same same same', {
      'same same same': 'same](https://same/same "same") same **same',
    });
    check('[**bold label**](<https://example.com>) tail', 'bold label tail', {
      'bold label': 'bold label',
      'tail': 'tail',
    });
  });

  test('CRLF, nested list prefixes and headings map to their body text', () {
    check('## 标题 ###\r\n', '标题', {'标题': '标题'}, kind: MarkdownBlockKind.heading);
    check('1. 1\r\n2. 2\r\n   - nested **word**\r\n', '12nested word', {
      '1': '1',
      '2': '2',
      'nested': 'nested',
      'word': 'word',
    }, kind: MarkdownBlockKind.list);
    check('first\r\nsecond', 'first\nsecond', {
      'first': 'first',
      '\n': '\r\n',
      'second': 'second',
    });
  });

  test(
    'fenced code uses body coordinates without its language or closing fence',
    () {
      check('```dart\r\ndart\r\n**literal**\r\n```\r\n', 'dart\n**literal**', {
        'dart': 'dart',
        '**literal**': '**literal**',
      }, kind: MarkdownBlockKind.code);
    },
  );

  test(
    'nested code with an empty first line keeps all newline coordinates',
    () {
      check(
        '- item\r\n\r\n  ```dart\r\n\r\n  code\r\n  ```\r\n',
        'item\ncode\n',
        {'item': 'item', 'code': 'code'},
        kind: MarkdownBlockKind.list,
      );
    },
  );
}
