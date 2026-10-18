import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  test('attribute decoding preserves Markdown punctuation in destinations', () {
    expect(
      markdownAttributeText('a*b*c_1_&amp;x=&quot;y&quot;'),
      'a*b*c_1_&x="y"',
    );
  });

  test('editing an encoded media address twice keeps percent escapes and label formatting', () {
    final editor = MarkdownEditorController(
      text: '[**Bold**](<docs/my%20file.md>)\n',
    );
    addTearDown(editor.dispose);
    for (var i = 0; i < 2; i++) {
      final target = editor.elementTarget(offset: 3);
      target.editMedia(target.media!.url, target.media!.description);
      expect(editor.text, '[**Bold**](<docs/my%20file.md>)\n');
    }
  });

  test('nested linked image targets the innermost element and final fence remains addressable', () {
    final editor = MarkdownEditorController(
      text: '[![alt](image.png)](https://example.com)\n',
    );
    addTearDown(editor.dispose);
    expect(editor.elementTarget(offset: 4).media!.image, isTrue);
    editor.session.replace('```dart\ncode\n```');
    expect(editor.elementTarget(offset: editor.text.length).code, 'code');
  });

  test(
    'formula editing uses bare source, preserves delimiter convention and undo',
    () {
      final editor = MarkdownEditorController(text: '\\[\r\nx^2\r\n\\]\r\n');
      addTearDown(editor.dispose);
      final target = editor.elementTarget(offset: 4);
      expect(target.code, 'x^2');
      target.editFormula('y^2\n+1');
      expect(editor.text, '\\[\r\ny^2\r\n+1\r\n\\]\r\n');
      editor.session.undo();
      expect(editor.text, '\\[\r\nx^2\r\n\\]\r\n');
    },
  );
  test(
    'CommonMark media coordinates preserve nested destinations and escapes',
    () {
      const source =
          '# Title\n\nBefore [**one**](https://example.com/a_(b) "Title") '
          r'and ![a\]b](<image path.png>) and `![not](image)`.';
      final editor = MarkdownEditorController(text: source);
      addTearDown(editor.dispose);
      final block = editor.document.blocks.last;
      final tokens = markdownMediaTargets(source, block);
      expect(tokens, hasLength(2));
      expect(
        tokens[0].range.slice(source),
        '[**one**](https://example.com/a_(b) "Title")',
      );
      expect(tokens[0].labelRange.slice(source), '**one**');
      expect(tokens[0].url, 'https://example.com/a_(b)');
      expect(tokens[0].description, 'one');
      expect(tokens[1].range.slice(source), r'![a\]b](<image path.png>)');
      expect(tokens[1].image, isTrue);
      expect(tokens[1].description, 'a]b');
    },
  );

  test(
    'reference media resolves definitions without editing shared references',
    () {
      const source =
          '[first][url] ![second][url]\n\n[url]: https://example.com "T"\n';
      final editor = MarkdownEditorController(text: source);
      addTearDown(editor.dispose);
      final tokens = markdownMediaTargets(source, editor.document.blocks.first);
      expect(tokens.map((t) => t.range.slice(source)), [
        '[first][url]',
        '![second][url]',
      ]);
      final target = editor.elementTarget(offset: 1);
      target.unlink();
      expect(
        editor.text,
        'first ![second][url]\n\n[url]: https://example.com "T"\n',
      );
      editor.session.undo();
      expect(editor.text, source);
    },
  );

  test('media edit safely serializes label destination and title', () {
    final editor = MarkdownEditorController(text: '![old](old.png)\n');
    addTearDown(editor.dispose);
    editor
        .elementTarget(offset: 3)
        .editMedia('new file.png', 'a[b]', title: '"T"');
    final tokens = markdownMediaTargets(
      editor.text,
      editor.document.blocks.first,
    );
    expect(tokens.single.url, 'new%20file.png');
    expect(tokens.single.description, 'a[b]');
    expect(tokens.single.title, '"T"');
    editor.session.undo();
    expect(editor.text, '![old](old.png)\n');
  });

  test(
    'list indent outdent and task toggle are source-precise and undoable',
    () {
      final editor = MarkdownEditorController(
        text: '- [ ] first\r\n  - second\r\n',
      );
      addTearDown(editor.dispose);
      editor.elementTarget(offset: 5).toggleTask();
      expect(editor.text, '- [x] first\r\n  - second\r\n');
      editor
          .elementTarget(offset: editor.text.indexOf('second'))
          .indent(2, reverse: true);
      expect(editor.text, '- [x] first\r\n- second\r\n');
      editor.session.undo();
      editor.session.undo();
      expect(editor.text, '- [ ] first\r\n  - second\r\n');
    },
  );

  test('code editing retains metadata CRLF and safe fences', () {
    final editor = MarkdownEditorController(
      text: '```dart title=x\r\nold\r\n```\r\n',
    );
    addTearDown(editor.dispose);
    editor.elementTarget(offset: 10).editCode('new\n```\nend', 'text');
    expect(editor.text, '````text title=x\r\nnew\r\n```\r\nend\r\n````\r\n');
    editor.session.undo();
    expect(editor.text, '```dart title=x\r\nold\r\n```\r\n');
  });

  test('stale element snapshots reject every mutation', () {
    final editor = MarkdownEditorController(text: '- [ ] first\n');
    addTearDown(editor.dispose);
    final target = editor.elementTarget(offset: 5);
    editor.session.replace('replacement');
    expect(target.deleteBlock, throwsStateError);
    expect(target.restoreSelection, throwsStateError);
    expect(target.toggleTask, throwsStateError);
    expect(() => target.indent(2), throwsStateError);
    expect(() => target.insertParagraph(above: true), throwsStateError);
    expect(editor.text, 'replacement');
  });

  test('selected copy variants use Markdown AST, not markup stripping', () {
    const text = '**Bold** and [link](https://example.com) ![alt](image.png)';
    final editor = MarkdownEditorController(text: text);
    addTearDown(editor.dispose);
    final target = editor.elementTarget(
      offset: 1,
      selection: const TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    expect(markdownPlainText(target.selected), 'Bold and link alt');
    expect(
      markdownHtmlFragment(target.selected, const MarkdownPreferences()),
      contains('<strong>Bold</strong>'),
    );
  });
}
