import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  test('italic and subscript do not remove bold or strikethrough markers', () {
    for (final (text, marker, expected) in [
      ('**word**', '*', '***word***'),
      ('~~word~~', '~', '~~~word~~~'),
    ]) {
      final editor = MarkdownEditorController(text: text);
      editor.select(2, 6);
      editor.toggleInline(marker);
      expect(editor.text, expected);
      editor.toggleInline(marker);
      expect(editor.text, text);
      editor.dispose();
    }
  });
  test(
    'paragraph conversion replaces prefixes across reversed CRLF selection',
    () {
      const original = '# First\r\n- [x] Second\r\nThird\r\nLast';
      final editor = MarkdownEditorController(text: original);
      addTearDown(editor.dispose);
      editor.select(original.indexOf('Last'), 2);
      editor.setParagraph('## ');
      expect(editor.text, '## First\r\n## Second\r\n## Third\r\nLast');
      expect(editor.selection.baseOffset, editor.text.indexOf('Last'));
      expect(editor.selection.extentOffset, 3);
      editor.session.undo();
      expect(editor.text, original);
      expect(editor.session.canUndo, isFalse);
    },
  );

  test('paragraph toggle and body conversion preserve the caret and following lines', () {
    final editor = MarkdownEditorController(text: '## Hello\nNext');
    addTearDown(editor.dispose);
    editor.select(5);
    editor.setParagraph('> ');
    expect(editor.text, '> Hello\nNext');
    expect(editor.selection.extentOffset, 4);
    editor.setParagraph('> ');
    expect(editor.text, 'Hello\nNext');
    editor.setParagraph('- [ ] ');
    editor.setParagraph('');
    expect(editor.text, 'Hello\nNext');
  });

  for (final marker in ['**', '*', '~~', '==', '^', '~', '`']) {
    test('$marker toggles without stacking and shares undo history', () {
      final editor = MarkdownEditorController(text: 'Before text after');
      addTearDown(editor.dispose);
      editor.select(7, 11);
      editor.toggleInline(marker);
      expect(editor.text, 'Before ${marker}text$marker after');
      expect(editor.selection.textInside(editor.text), 'text');
      editor.toggleInline(marker);
      expect(editor.text, 'Before text after');
      editor.session.undo();
      expect(editor.text, 'Before ${marker}text$marker after');
      editor.session.undo();
      expect(editor.text, 'Before text after');
    });
  }

  test(
    'clear formatting retains link text, image alt, code and line boundaries',
    () {
      final editor = MarkdownEditorController(
        text: '# Title\r\n\r\n**Bold** [link](https://example.org) ![picture](photo.png)\r\n\r\n- One\r\n- Two\r\n\r\n```text\r\n**literal**\r\n```',
      );
      addTearDown(editor.dispose);
      final original = editor.text;
      editor.select(0, editor.text.length);
      editor.clearFormatting();
      expect(
        editor.text,
        'Title\r\n\r\nBold link picture\r\n\r\nOne\r\nTwo\r\n\r\n**literal**',
      );
      editor.session.undo();
      expect(editor.text, original);
    },
  );

  test('block commands preserve CRLF, selection and one-step undo', () {
    const original = 'Before\r\n\r\nformula\r\n\r\nAfter';
    final editor = MarkdownEditorController(text: original);
    addTearDown(editor.dispose);
    final offset = original.indexOf('formula');
    editor.select(offset, offset + 7);
    editor.insertCodeBlock(math: true);
    expect(editor.text, 'Before\r\n\r\n\$\$\r\nformula\r\n\$\$\r\n\r\nAfter');
    expect(editor.selection.textInside(editor.text), 'formula');
    editor.session.undo();
    expect(editor.text, original);
    expect(editor.session.canUndo, isFalse);
    editor.select(offset, offset + 7);
    editor.insertBlock('---');
    expect(editor.text, 'Before\r\n\r\n---\r\n\r\nAfter');
  });

  test('code insertion chooses a fence longer than selected backticks', () {
    final editor = MarkdownEditorController(text: '```dart\ncode\n```');
    addTearDown(editor.dispose);
    editor.select(0, editor.text.length);
    editor.insertCodeBlock();
    expect(editor.text, '````\n```dart\ncode\n```\n````\n\n');
    expect(editor.selection.textInside(editor.text), '```dart\ncode\n```');
  });

  test(
    'footnote uses a unique label, selects definition and undoes atomically',
    () {
      final editor = MarkdownEditorController(
        text: 'Existing[^1]\r\n\r\n[^1]: first\r\n\r\nNew',
      );
      addTearDown(editor.dispose);
      final original = editor.text;
      editor.select(original.length - 3, original.length);
      editor.insertFootnote();
      expect(
        editor.text,
        'Existing[^1]\r\n\r\n[^1]: first\r\n\r\n[^2]\r\n\r\n[^2]: New\r\n',
      );
      expect(editor.selection.textInside(editor.text), 'New');
      editor.session.undo();
      expect(editor.text, original);
      expect(editor.session.canUndo, isFalse);
    },
  );
}
