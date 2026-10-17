import 'package:flutter/material.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

final class MarkdownEditorController extends ChangeNotifier {
  MarkdownEditorController({MarkdownSession? session, String text = ''})
    : session = session ?? MarkdownSession(text) {
    source = TextEditingController(text: this.session.text);
    source.addListener(_inputChanged);
    this.session.addListener(_documentChanged);
  }
  final MarkdownSession session;
  late final TextEditingController source;
  final sourceFocus = FocusNode();
  bool _syncing = false;
  String get text =>
      source.value.composing.isValid ? source.text : session.text;
  MarkdownDocument get document => session.document;
  TextSelection get selection => source.selection;

  void _inputChanged() {
    if (_syncing) return;
    if (source.value.composing.isValid && !source.value.composing.isCollapsed) {
      return;
    }
    if (source.text != session.text) {
      session.replace(source.text, mergeKey: 'source-typing');
    } else {
      notifyListeners();
    }
  }

  void _documentChanged() {
    if (source.text != session.text) {
      final selection = source.selection;
      _syncing = true;
      source.value = TextEditingValue(
        text: session.text,
        selection: TextSelection(
          baseOffset: selection.baseOffset.clamp(0, session.text.length),
          extentOffset: selection.extentOffset.clamp(0, session.text.length),
        ),
      );
      _syncing = false;
    }
    notifyListeners();
  }

  void select(int start, [int? end]) {
    source.selection = TextSelection(
      baseOffset: start.clamp(0, source.text.length),
      extentOffset: (end ?? start).clamp(0, source.text.length),
    );
  }

  void replaceSelection(String replacement, {String label = '插入内容'}) {
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    session.patch(
      TextPatch(SourceRange(start, end), replacement),
      label: label,
    );
    select(start + replacement.length);
  }

  void surround(String prefix, [String? suffix]) {
    final range = selection.isValid
        ? SourceRange(selection.start, selection.end)
        : SourceRange(text.length, text.length);
    final selected = range.slice(text);
    session.patch(
      TextPatch(range, '$prefix$selected${suffix ?? prefix}'),
      label: '设置文字格式',
    );
    select(
      range.start + prefix.length,
      range.start + prefix.length + selected.length,
    );
  }

  void linePrefix(String prefix) {
    final offset = selection.isValid ? selection.start : text.length;
    final lineStart = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    session.patch(
      TextPatch(SourceRange(lineStart, lineStart), prefix),
      label: '插入段落格式',
    );
    select(offset + prefix.length);
  }

  /// Inserts a Markdown table; [rows] includes the header row.
  void insertTable({required int rows, required int columns}) {
    RangeError.checkValueInInterval(rows, 1, 100, 'rows');
    RangeError.checkValueInInterval(columns, 1, 20, 'columns');
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newline = document.newline;
    final before = text.substring(0, start), after = text.substring(end);
    final prefix = before.isEmpty || before.endsWith('$newline$newline')
        ? ''
        : before.endsWith(newline)
        ? newline
        : '$newline$newline';
    final suffix = after.startsWith('$newline$newline')
        ? ''
        : after.startsWith(newline)
        ? newline
        : '$newline$newline';
    String row(List<String> cells) => '| ${cells.join(' | ')} |';
    final table = [
      row(List.generate(columns, (index) => '标题${index + 1}')),
      row(List.filled(columns, '---')),
      for (var index = 1; index < rows; index++) row(List.filled(columns, '')),
    ].join(newline);
    replaceSelection('$prefix$table$suffix', label: '插入表格');
    select(start + prefix.length + 2, start + prefix.length + 5);
  }

  List<SourceRange> find(
    String query, {
    bool caseSensitive = false,
    bool regularExpression = false,
    bool wholeWord = false,
  }) {
    if (query.isEmpty) return const [];
    var pattern = regularExpression ? query : RegExp.escape(query);
    if (wholeWord) {
      pattern = '(?<![\\p{L}\\p{N}_])(?:$pattern)(?![\\p{L}\\p{N}_])';
    }
    return RegExp(pattern, caseSensitive: caseSensitive, unicode: true)
        .allMatches(text)
        .where((m) => m.start != m.end)
        .map((m) => SourceRange(m.start, m.end))
        .toList();
  }

  void replaceAll(
    String query,
    String replacement, {
    bool caseSensitive = false,
    bool regularExpression = false,
    bool wholeWord = false,
  }) {
    final ranges = find(
      query,
      caseSensitive: caseSensitive,
      regularExpression: regularExpression,
      wholeWord: wholeWord,
    );
    var updated = text;
    for (final range in ranges.reversed) {
      updated = updated.replaceRange(range.start, range.end, replacement);
    }
    session.replace(updated, label: '全部替换');
  }

  @override
  void dispose() {
    session.removeListener(_documentChanged);
    source.removeListener(_inputChanged);
    source.dispose();
    sourceFocus.dispose();
    super.dispose();
  }
}
