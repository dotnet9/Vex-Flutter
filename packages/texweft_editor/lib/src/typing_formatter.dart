import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

export 'pair_formatter.dart';

void indentMarkdownSelection(
  TextEditingController controller,
  int size, {
  bool reverse = false,
}) {
  final value = controller.value, selection = controller.selection;
  if (!selection.isValid || !value.composing.isCollapsed) return;
  final start = selection.start == 0
      ? 0
      : value.text.lastIndexOf('\n', selection.start - 1) + 1;
  if (selection.isCollapsed && !reverse) {
    final spaces = ' ' * (size - (selection.start - start) % size);
    controller.value = TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, spaces),
      selection: TextSelection.collapsed(
        offset: selection.start + spaces.length,
      ),
    );
    return;
  }
  final end = selection.end > start && value.text[selection.end - 1] == '\n'
      ? selection.end - 1
      : selection.end;
  var base = selection.baseOffset, extent = selection.extentOffset;
  final edits = <(int, int, String)>[];
  for (var offset = start; offset <= end;) {
    final count = reverse
        ? RegExp(r'^ {1,8}')
                  .firstMatch(value.text.substring(offset))
                  ?.group(0)
                  ?.length ??
              0
        : 0;
    edits.add((
      offset,
      reverse ? count.clamp(0, size) : 0,
      reverse ? '' : ' ' * size,
    ));
    final next = value.text.indexOf('\n', offset);
    if (next < 0) break;
    offset = next + 1;
  }
  var text = value.text;
  for (final (offset, removed, inserted) in edits.reversed) {
    text = text.replaceRange(offset, offset + removed, inserted);
    int adjusted(int position) => position < offset
        ? position
        : position < offset + removed
        ? offset
        : position + inserted.length - removed;
    base = adjusted(base);
    extent = adjusted(extent);
  }
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: base, extentOffset: extent),
  );
}

/// Continues a list or quotation when Enter inserts a single line break.
/// Pasted blocks, composing text and fenced code keep platform input unchanged.
final class MarkdownTypingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!oldValue.selection.isValid ||
        !oldValue.selection.isCollapsed ||
        !newValue.selection.isCollapsed ||
        (oldValue.composing.isValid && !oldValue.composing.isCollapsed) ||
        (newValue.composing.isValid && !newValue.composing.isCollapsed)) {
      return newValue;
    }
    final offset = oldValue.selection.extentOffset;
    final insertedLength = newValue.text.length - oldValue.text.length;
    if (insertedLength < 1 ||
        insertedLength > 2 ||
        newValue.selection.extentOffset != offset + insertedLength) {
      return newValue;
    }
    final inserted = newValue.text.substring(offset, offset + insertedLength);
    if ((inserted != '\n' && inserted != '\r\n') ||
        oldValue.text.replaceRange(offset, offset, inserted) != newValue.text) {
      return newValue;
    }
    final newline = oldValue.text.contains('\r\n') ? '\r\n' : inserted;
    final plainValue = newline == inserted
        ? newValue
        : TextEditingValue(
            text: oldValue.text.replaceRange(offset, offset, newline),
            selection: TextSelection.collapsed(offset: offset + newline.length),
          );
    if (MarkdownDocument.parse(oldValue.text).blocks.any(
      (block) =>
          block.kind == MarkdownBlockKind.code &&
          block.range.start <= offset &&
          offset <= block.range.end,
    )) {
      return plainValue;
    }
    final before = oldValue.text.substring(0, offset);
    final lineStart = before.lastIndexOf(RegExp(r'[\r\n]')) + 1;
    final line = before.substring(lineStart);
    final quote =
        RegExp(r'^ {0,3}(?:>[ \t]?)+[ \t]*').firstMatch(line)?.group(0) ?? '';
    final rest = line.substring(quote.length);
    final list = RegExp(
      r'^([ \t]*)([-+*]|\d{1,9}[.)])([ \t]+)(\[[ xX]\][ \t]+)?',
    ).firstMatch(rest);
    if (quote.isEmpty && list == null) return plainValue;

    final suffix = oldValue.text
        .substring(offset)
        .split(RegExp(r'[\r\n]'))
        .first;
    final empty = '${list == null ? rest : rest.substring(list.end)}$suffix'
        .trim()
        .isEmpty;
    String prefix;
    var start = offset;
    if (empty) {
      start = lineStart;
      // An empty item exits the list. An empty quote exits one quote level.
      prefix = list != null
          ? quote
          : quote.replaceFirst(RegExp(r'>[ \t]*$'), '');
      final replacement = '$prefix$newline';
      return TextEditingValue(
        text: oldValue.text.replaceRange(start, offset, replacement),
        selection: TextSelection.collapsed(offset: start + replacement.length),
      );
    }
    if (list == null) {
      prefix = quote;
    } else {
      final marker = list[2]!;
      final ordered = RegExp(r'^(\d+)([.)])$').firstMatch(marker);
      final next = ordered == null
          ? marker
          : '${int.parse(ordered[1]!) + 1}${ordered[2]}';
      final task = list[4] == null
          ? ''
          : list[4]!.replaceFirst(RegExp(r'[xX]'), ' ');
      prefix = '$quote${list[1]}$next${list[3]}$task';
    }
    final replacement = '$newline$prefix';
    return TextEditingValue(
      text: oldValue.text.replaceRange(offset, offset, replacement),
      selection: TextSelection.collapsed(offset: offset + replacement.length),
    );
  }
}
