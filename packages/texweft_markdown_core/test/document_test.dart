import 'package:test/test.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

void main() {
  test('unclosed metadata remains ordinary Markdown', () {
    expect(MarkdownDocument.parse('---\n# 正文\n').headings.single.title, '正文');
  });
  test(
    'checkpoint restores content, saved state and both history branches',
    () {
      final session = MarkdownSession('原文');
      session.replace('第一版');
      session.markSaved();
      session.replace('第二版');
      session.undo();
      final snapshot = session.snapshot();
      session.replace('临时演练');
      session.restore(snapshot);
      expect(session.text, '第一版');
      expect(session.isDirty, isFalse);
      session.redo();
      expect(session.text, '第二版');
      session.undo();
      session.undo();
      expect(session.text, '原文');
      expect(() => MarkdownSession().restore(snapshot), throwsArgumentError);
    },
  );
  test('ignores headings in fenced code and metadata; preserves CRLF offsets', () {
    const text =
        '---\r\nname: 测试\r\n---\r\n# 标题 🧵\r\n\r\n```md\r\n## 代码\r\n```\r\n\r\n## 正文\r\n内容';
    final doc = MarkdownDocument.parse(text);
    expect(doc.headings.map((h) => h.title), ['标题 🧵', '正文']);
    expect(doc.headings.last.header.slice(text), '## 正文\r\n');
    expect(doc.newline, '\r\n');
    expect(doc.position(text.indexOf('正文')), (line: 10, column: 4));
  });
  test('setext headings, duplicate identifiers and nested ancestry', () {
    final doc = MarkdownDocument.parse('标题\n===\n\n## 同名\n\n### 子级\n\n## 同名\n');
    expect(doc.headings.map((h) => h.level), [1, 2, 3, 2]);
    expect(doc.headings[1].id, isNot(doc.headings[3].id));
    expect(doc.headings[2].parentId, doc.headings[1].id);
    expect(doc.headings[1].section.slice(doc.source), contains('### 子级'));
  });
  test(
    'chapter commands preserve bodies, descendants and reversible history',
    () {
      const text = '# 根\n\n## 甲\n\n甲正文\n\n### 子\n\n子正文\n\n## 乙\n\n乙正文\n';
      final session = MarkdownSession(text);
      final a = session.document.headings[1];
      session.moveHeading(a.id, 1);
      expect(
        session.text.indexOf('## 乙'),
        lessThan(session.text.indexOf('## 甲')),
      );
      expect(session.text, contains('子正文'));
      session.undo();
      expect(session.text, text);
      session.redo();
      expect(
        session.text.indexOf('## 乙'),
        lessThan(session.text.indexOf('## 甲')),
      );
      session.undo();
      session.deleteHeading(a.id, keepContents: true);
      expect(session.text, isNot(contains('## 甲')));
      expect(session.text, contains('甲正文'));
      expect(session.text, contains('### 子'));
      session.undo();
      expect(session.text, text);
      session.renameHeading(a.id, '甲改名');
      expect(session.text, contains('## 甲改名\n\n甲正文'));
    },
  );
  test('rejects cyclic reparenting and level overflow atomically', () {
    const text = '# 根\n\n## 父\n\n###### 子\n';
    final session = MarkdownSession(text);
    expect(
      () => session.reparentHeading(
        session.document.headings[1].id,
        session.document.headings[2].id,
      ),
      throwsStateError,
    );
    expect(
      () => session.changeLevel(session.document.headings[1].id, 1),
      throwsStateError,
    );
    expect(session.text, text);
    expect(session.canUndo, isFalse);
  });
  test('saved marker follows actual content across undo and new branches', () {
    final session = MarkdownSession('原文');
    session.replace('版本一');
    session.markSaved();
    session.replace('版本二');
    expect(session.isDirty, isTrue);
    session.undo();
    expect(session.isDirty, isFalse);
    session.replace('新分支');
    expect(session.canRedo, isFalse);
    session.undo();
    expect(session.text, '版本一');
  });
  test('text patches validate UTF-16 source boundaries', () {
    const text = 'a🧵b';
    expect(const TextPatch(SourceRange(1, 3), '线').apply(text), 'a线b');
    expect(
      () => const TextPatch(SourceRange(0, 10), '').apply(text),
      throwsRangeError,
    );
  });
}
