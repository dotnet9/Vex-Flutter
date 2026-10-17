import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  final formatter = MarkdownTypingFormatter();
  TextEditingValue enter(String source, {int? at}) {
    final offset = at ?? source.length;
    return formatter.formatEditUpdate(
      TextEditingValue(
        text: source,
        selection: TextSelection.collapsed(offset: offset),
      ),
      TextEditingValue(
        text: source.replaceRange(offset, offset, '\n'),
        selection: TextSelection.collapsed(offset: offset + 1),
      ),
    );
  }

  test(
    'Enter continues ordered, task and quoted nested lists at the caret',
    () {
      final ordered = enter('9) 第九项');
      expect(ordered.text, '9) 第九项\n10) ');
      expect(ordered.selection.extentOffset, ordered.text.length);
      expect(enter('- [x] 已完成').text, '- [x] 已完成\n- [ ] ');
      expect(enter('>   - 第一项').text, '>   - 第一项\n>   - ');
      expect(enter('- 前半后半', at: 4).text, '- 前半\n- 后半');
      expect(enter('> 引用').text, '> 引用\n> ');
      expect(enter('1. 第一项\r\n2. 第二项').text, '1. 第一项\r\n2. 第二项\r\n3. ');
    },
  );

  test(
    'an empty item or quote exits without changing following paragraphs',
    () {
      expect(enter('- 正文\n- ').text, '- 正文\n\n');
      expect(enter('- \n\n后文', at: 2).text, '\n\n\n后文');
      expect(enter('> > ').text, '> \n');
      expect(enter('> ').text, '\n');
    },
  );

  test('code, pasted blocks and uncommitted IME input stay literal', () {
    expect(enter('```text\n- 代码').text, '```text\n- 代码\n');
    expect(enter('```text\r\n- 代码').text, '```text\r\n- 代码\r\n');
    expect(enter('前文\r\n后文').text, '前文\r\n后文\r\n');
    const before = TextEditingValue(
      text: '- 中文',
      selection: TextSelection.collapsed(offset: 4),
    );
    const paste = TextEditingValue(
      text: '- 中文\n多行',
      selection: TextSelection.collapsed(offset: 7),
    );
    expect(formatter.formatEditUpdate(before, paste), paste);
    const composition = TextEditingValue(
      text: '- 中文\n',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 2, end: 5),
    );
    expect(formatter.formatEditUpdate(before, composition), composition);
  });
}
