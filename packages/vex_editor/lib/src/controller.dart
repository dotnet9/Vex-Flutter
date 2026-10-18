import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:vex_markdown_core/vex_markdown_core.dart';

import 'markdown_preferences.dart';
import 'markdown_syntax.dart';

final class MarkdownRevealRequest {
  const MarkdownRevealRequest(this.selection);
  final TextSelection selection;
}

final class MarkdownEditorController extends ChangeNotifier {
  MarkdownEditorController({MarkdownSession? session, String text = ''})
    : session = session ?? MarkdownSession(text) {
    _documentRevision = this.session.revision;
    source = TextEditingController(text: this.session.text);
    source.addListener(_inputChanged);
    this.session.addListener(_documentChanged);
  }
  final MarkdownSession session;
  late final TextEditingController source;
  final sourceFocus = FocusNode();
  final navigation = ValueNotifier<MarkdownRevealRequest?>(null);
  bool _syncing = false;
  late int _documentRevision;
  String get text =>
      source.value.composing.isValid ? source.text : session.text;
  MarkdownDocument get document => session.document;
  TextSelection get selection => source.selection;
  MarkdownDocument? _countedDocument;
  int _characterCount = 0;

  int get characterCount {
    if (!identical(_countedDocument, document)) {
      _characterCount = session.text.characters.length;
      _countedDocument = document;
    }
    return _characterCount;
  }

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
    final textChanged = _documentRevision != session.revision;
    _documentRevision = session.revision;
    if (textChanged) navigation.value = null;
    // Saving changes the disk baseline, not an in-progress IME candidate.
    if (textChanged && source.text != session.text) {
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

  /// Explicit navigation is separate from selections changed while typing.
  void reveal(int start, {int? end}) {
    select(start, end);
    navigation.value = MarkdownRevealRequest(selection);
    notifyListeners();
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

  void toggleInline(String marker) {
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = text.substring(start, end);
    bool removable(String before, String after) {
      if (marker != '*' && marker != '~') return true;
      final leading =
          RegExp('^${RegExp.escape(marker)}+')
              .firstMatch(after)
              ?.group(0)
              ?.length ??
          0;
      final trailing =
          RegExp('${RegExp.escape(marker)}+\$')
              .firstMatch(before)
              ?.group(0)
              ?.length ??
          0;
      return leading.isOdd && trailing.isOdd;
    }

    if (start >= marker.length &&
        text.substring(start - marker.length, start) == marker &&
        text.substring(end).startsWith(marker) &&
        removable(text.substring(0, start), text.substring(end))) {
      session.patch(
        TextPatch(
          SourceRange(start - marker.length, end + marker.length),
          selected,
        ),
        label: '清除文字格式',
      );
      select(start - marker.length, end - marker.length);
    } else if (selected.length >= marker.length * 2 &&
        selected.startsWith(marker) &&
        selected.endsWith(marker) &&
        removable(selected, selected)) {
      final content = selected.substring(
        marker.length,
        selected.length - marker.length,
      );
      replaceSelection(content, label: '清除文字格式');
      select(start, start + content.length);
    } else {
      surround(marker);
    }
  }

  /// Converts selected lines in one history entry, without stacking prefixes.
  void setParagraph(String prefix) {
    final old = text;
    final selection = this.selection.isValid
        ? this.selection
        : TextSelection.collapsed(offset: old.length);
    final start = selection.start == 0
        ? 0
        : old.lastIndexOf('\n', selection.start - 1) + 1;
    final last =
        selection.end > selection.start && old[selection.end - 1] == '\n'
        ? selection.end - 1
        : selection.end;
    final next = old.indexOf('\n', last);
    final end = next == -1 ? old.length : next;
    final original = old.substring(start, end);
    final lines = original.split('\n');
    final pattern = RegExp(
      r'^( {0,3})(?:#{1,6}[ \t]+|>[ \t]?|(?:[-+*]|\d+[.)])[ \t]+(?:\[[ xX]\][ \t]+)?)',
    );
    final toggleOff =
        prefix.isNotEmpty && lines.every((line) => line.startsWith(prefix));
    final edits = <(int, int, String)>[];
    var offset = start;
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      final removed = match?.end ?? 0;
      final replacement = toggleOff ? '' : '${match?[1] ?? ''}$prefix';
      edits.add((offset, removed, replacement));
      offset += line.length + 1;
    }
    var updated = old;
    for (final (offset, count, replacement) in edits.reversed) {
      updated = updated.replaceRange(offset, offset + count, replacement);
    }
    int mapped(int position) {
      var delta = 0;
      for (final (offset, count, replacement) in edits) {
        if (position < offset) break;
        if (position <= offset + count) {
          return offset + delta + replacement.length;
        }
        delta += replacement.length - count;
      }
      return position + delta;
    }

    session.replace(updated, label: '设置段落格式');
    select(mapped(selection.baseOffset), mapped(selection.extentOffset));
  }

  void clearFormatting() {
    final start = selection.isValid ? selection.start : 0;
    final end = selection.isValid ? selection.end : text.length;
    if (start == end) {
      setParagraph('');
      return;
    }
    const preferences = MarkdownPreferences();
    final parser = md.Document(
      extensionSet: MarkdownSyntax.extensions(preferences),
      inlineSyntaxes: MarkdownSyntax.inlines(preferences),
      blockSyntaxes: MarkdownSyntax.blocks(preferences),
      encodeHtml: false,
    );
    String plainNode(md.Node node) {
      if (node is! md.Element) return node.textContent;
      if (node.tag == 'img') return node.attributes['alt'] ?? '';
      if (node.tag == 'br') return document.newline;
      final separator = switch (node.tag) {
        'ul' || 'ol' || 'table' || 'thead' || 'tbody' => document.newline,
        'tr' => '\t',
        _ => '',
      };
      return node.children?.map(plainNode).join(separator) ?? '';
    }

    final plain = parser
        .parseLines(text.substring(start, end).split(RegExp(r'\r?\n')))
        .map((node) => plainNode(node).trimRight())
        .join('${document.newline}${document.newline}');
    replaceSelection(plain, label: '清除格式');
    select(start, start + plain.length);
  }

  int insertBlock(String content, {String label = '插入内容'}) {
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
    final normalized = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', newline);
    replaceSelection('$prefix$normalized$suffix', label: label);
    return start + prefix.length;
  }

  void insertCodeBlock({bool math = false}) {
    final selected = selection.isValid ? selection.textInside(text) : '';
    final newline = document.newline;
    final open = math
        ? r'$$'
        : '`' *
              ((RegExp(r'`+')
                      .allMatches(selected)
                      .fold<int>(
                        2,
                        (length, match) => match[0]!.length > length
                            ? match[0]!.length
                            : length,
                      )) +
                  1);
    final start = insertBlock(
      '$open$newline$selected$newline$open',
      label: math ? '插入公式块' : '插入代码块',
    );
    select(
      start + open.length + newline.length,
      start + open.length + newline.length + selected.length,
    );
  }

  void insertFootnote() {
    var number = 1;
    while (text.contains('[^$number]')) {
      number++;
    }
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final content = text.substring(start, end);
    final newline = document.newline;
    final body = text.replaceRange(start, end, '[^$number]');
    final separator = body.endsWith('$newline$newline')
        ? ''
        : body.endsWith(newline)
        ? newline
        : '$newline$newline';
    final definition = '[^$number]: ';
    session.replace(
      '$body$separator$definition$content$newline',
      label: '插入脚注',
    );
    select(
      body.length + separator.length + definition.length,
      body.length + separator.length + definition.length + content.length,
    );
  }

  void insertMermaid(String source) {
    final newline = document.newline;
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final fence = MarkdownCodeFence.parse('```mermaid\n\n```')!;
    final block = fence
        .replace(code: normalized, language: 'mermaid')
        .replaceAll('\n', newline);
    final start = insertBlock(block, label: '插入 Mermaid 图表');
    select(start + '```mermaid$newline'.length);
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
  void insertTable({
    required int rows,
    required int columns,
    String Function(int column)? columnLabel,
  }) {
    RangeError.checkValueInInterval(rows, 1, 100, 'rows');
    RangeError.checkValueInInterval(columns, 1, 20, 'columns');
    final newline = document.newline;
    String row(List<String> cells) => '| ${cells.join(' | ')} |';
    final headers = List.generate(
      columns,
      (index) => columnLabel?.call(index + 1) ?? '标题${index + 1}',
    );
    final table = [
      row(headers),
      row(List.filled(columns, '---')),
      for (var index = 1; index < rows; index++) row(List.filled(columns, '')),
    ].join(newline);
    final start = insertBlock(table, label: '插入表格');
    select(start + 2, start + 2 + headers.first.length);
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
    navigation.dispose();
    super.dispose();
  }
}
