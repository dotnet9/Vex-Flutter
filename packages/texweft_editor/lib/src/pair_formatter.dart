import 'package:flutter/services.dart';

/// Pair only single-character edits. Paste and IME composition stay untouched.
final class MarkdownPairFormatter extends TextInputFormatter {
  const MarkdownPairFormatter();
  static const _pairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
    '`': '`',
  };
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final selection = oldValue.selection;
    if (!selection.isValid ||
        !newValue.selection.isCollapsed ||
        (oldValue.composing.isValid && !oldValue.composing.isCollapsed) ||
        (newValue.composing.isValid && !newValue.composing.isCollapsed)) {
      return newValue;
    }
    final start = selection.start, end = selection.end;
    final delta = newValue.text.length - oldValue.text.length;
    if (selection.isCollapsed &&
        delta == -1 &&
        start > 0 &&
        start < oldValue.text.length &&
        _pairs[oldValue.text[start - 1]] == oldValue.text[start] &&
        newValue.text == oldValue.text.replaceRange(start - 1, start, '')) {
      return TextEditingValue(
        text: oldValue.text.replaceRange(start - 1, start + 1, ''),
        selection: TextSelection.collapsed(offset: start - 1),
      );
    }
    if (delta != 1 - (end - start) ||
        newValue.selection.extentOffset != start + 1 ||
        start >= newValue.text.length) {
      return newValue;
    }
    final symbol = newValue.text[start];
    if (oldValue.text.replaceRange(start, end, symbol) != newValue.text) {
      return newValue;
    }
    if (selection.isCollapsed &&
        start < oldValue.text.length &&
        _pairs.values.contains(symbol) &&
        oldValue.text[start] == symbol) {
      return TextEditingValue(
        text: oldValue.text,
        selection: TextSelection.collapsed(offset: start + 1),
      );
    }
    final closing = _pairs[symbol];
    if (closing == null) return newValue;
    if (selection.isCollapsed) {
      final next = start < oldValue.text.length ? oldValue.text[start] : '';
      if (next.isNotEmpty && !RegExp(r'[\s\)\]\}]').hasMatch(next)) {
        return newValue;
      }
      if ((symbol == "'" || symbol == '"') &&
          start > 0 &&
          RegExp(r'[\w]').hasMatch(oldValue.text[start - 1])) {
        return newValue;
      }
    }
    final selected = oldValue.text.substring(start, end);
    return TextEditingValue(
      text: oldValue.text.replaceRange(start, end, '$symbol$selected$closing'),
      selection: selection.isCollapsed
          ? TextSelection.collapsed(offset: start + 1)
          : TextSelection(
              baseOffset: start + 1,
              extentOffset: start + selected.length + 1,
            ),
    );
  }
}
