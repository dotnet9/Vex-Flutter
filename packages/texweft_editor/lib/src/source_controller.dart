import 'dart:async';

import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import 'controller.dart';
import 'typing_formatter.dart';

/// Bridges the viewport editor to the authoritative source and shared history.
/// Line endings are a display projection, never a document-wide conversion.
final class MarkdownSourceEditingController
    extends CodeLineEditingControllerDelegate {
  MarkdownSourceEditingController(this.editor)
    : super(delegate: CodeLineEditingController()) {
    _projection = _SourceProjection(editor.source.text);
    _readSource();
    editor.source.addListener(_readSource);
    addListener(_writeSource);
  }

  final MarkdownEditorController editor;
  late _SourceProjection _projection;
  CodeLines? _lastLines;
  bool _syncing = false;
  bool _disposed = false;

  void _readSource() {
    if (_syncing) return;
    _syncing = true;
    try {
      final source = editor.source.value;
      final changed = source.text != _projection.source;
      if (changed) _projection = _SourceProjection(source.text);
      final lines = changed || _lastLines == null
          ? CodeLines.fromText(_projection.display)
          : codeLines;
      final base = _projection.position(source.selection.baseOffset);
      final extent = _projection.position(source.selection.extentOffset);
      final composingStart = _projection.position(source.composing.start);
      final composingEnd = _projection.position(source.composing.end);
      _lastLines = lines;
      value = CodeLineEditingValue(
        codeLines: lines,
        selection: CodeLineSelection(
          baseIndex: base.index,
          baseOffset: base.offset,
          extentIndex: extent.index,
          extentOffset: extent.offset,
          baseAffinity: source.selection.affinity,
          extentAffinity: source.selection.affinity,
        ),
        composing:
            source.composing.isValid &&
                composingStart.index == base.index &&
                composingEnd.index == base.index
            ? TextRange(start: composingStart.offset, end: composingEnd.offset)
            : TextRange.empty,
      );
      // The session owns undo. Do not retain a second full-document history.
      delegate.clearHistory();
    } finally {
      _syncing = false;
    }
  }

  void _writeSource() {
    if (_syncing) return;
    _syncing = true;
    try {
      if (!identical(_lastLines, codeLines)) {
        final display = text;
        if (display != _projection.display) {
          _projection = _SourceProjection(
            _projection.apply(
              display,
              editor.document.newline,
              preValue?.selection,
              selection,
            ),
          );
        }
        _lastLines = codeLines;
      }
      final selected = selection;
      editor.source.value = TextEditingValue(
        text: _projection.source,
        selection: TextSelection(
          baseOffset: _projection.offset(selected.base),
          extentOffset: _projection.offset(selected.extent),
          affinity: selected.extentAffinity,
        ),
        // Re-Editor's composing offsets are local to the active line.
        composing: composing.isValid && selected.isSameLine
            ? TextRange(
                start: _projection.offset(
                  CodeLinePosition(
                    index: selected.baseIndex,
                    offset: composing.start,
                  ),
                ),
                end: _projection.offset(
                  CodeLinePosition(
                    index: selected.baseIndex,
                    offset: composing.end,
                  ),
                ),
              )
            : TextRange.empty,
      );
      delegate.clearHistory();
    } finally {
      _syncing = false;
    }
  }

  @override
  bool get canUndo => editor.session.canUndo;
  @override
  bool get canRedo => editor.session.canRedo;
  @override
  void undo() {
    if (!isComposing) editor.session.undo();
  }

  @override
  void redo() {
    if (!isComposing) editor.session.redo();
  }

  @override
  Future<void> copy() => Clipboard.setData(
    ClipboardData(
      text: editor.selection.isCollapsed
          ? _projection.line(selection.baseIndex)
          : editor.selection.textInside(editor.source.text),
    ),
  );

  @override
  void cut() {
    if (isComposing) return;
    if (selection.isCollapsed) selectLine(selection.baseIndex);
    unawaited(copy());
    editor.replaceSelection('');
  }

  @override
  void paste() => unawaited(_paste());

  Future<void> _paste() async {
    if (isComposing) return;
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (_disposed || clipboard?.text == null || isComposing) return;
    editor.replaceSelection(clipboard!.text!);
    makeCursorVisible();
  }

  @override
  void applyNewLine() {
    if (isComposing) return;
    final previous = editor.source.value;
    final selected = previous.selection;
    final start = selected.isValid ? selected.start : previous.text.length;
    final end = selected.isValid ? selected.end : start;
    final newline = editor.document.newline;
    final next = TextEditingValue(
      text: previous.text.replaceRange(start, end, newline),
      selection: TextSelection.collapsed(offset: start + newline.length),
    );
    editor.source.value = MarkdownTypingFormatter().formatEditUpdate(
      previous,
      next,
    );
    makeCursorVisible();
  }

  @override
  void dispose() {
    _disposed = true;
    editor.source.removeListener(_readSource);
    removeListener(_writeSource);
    super.dispose();
  }
}

/// Maps line/column positions to original UTF-16 offsets, including a final
/// empty line. Cached indexes keep selection-only updates independent of size.
final class _SourceProjection {
  _SourceProjection(this.source) {
    final buffer = StringBuffer();
    var start = 0;
    for (final match in RegExp(r'\r\n|\n|\r').allMatches(source)) {
      final line = source.substring(start, match.start);
      _lengths.add(line.length);
      buffer
        ..write(line)
        ..write('\n');
      start = match.end;
      _sourceStarts.add(start);
      _displayStarts.add(buffer.length);
    }
    final last = source.substring(start);
    _lengths.add(last.length);
    buffer.write(last);
    display = buffer.toString();
  }

  final String source;
  late final String display;
  final _sourceStarts = <int>[0];
  final _displayStarts = <int>[0];
  final _lengths = <int>[];

  int _lineAt(List<int> starts, int offset) {
    var low = 0, high = starts.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (starts[middle] <= offset) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  CodeLinePosition position(int offset) {
    final safe = offset.clamp(0, source.length);
    final line = _lineAt(_sourceStarts, safe);
    return CodeLinePosition(
      index: line,
      offset: (safe - _sourceStarts[line]).clamp(0, _lengths[line]),
    );
  }

  int offset(CodeLinePosition position) {
    final line = position.index.clamp(0, _sourceStarts.length - 1);
    return _sourceStarts[line] + position.offset.clamp(0, _lengths[line]);
  }

  String line(int index) {
    final start = _sourceStarts[index];
    return source.substring(start, start + _lengths[index]);
  }

  int _sourceOffset(int displayOffset) {
    final line = _lineAt(_displayStarts, displayOffset);
    return _sourceStarts[line] + displayOffset - _displayStarts[line];
  }

  int _displayOffset(CodeLinePosition position) {
    final line = position.index.clamp(0, _displayStarts.length - 1);
    return _displayStarts[line] + position.offset.clamp(0, _lengths[line]);
  }

  String apply(
    String updated,
    String newline,
    CodeLineSelection? previous,
    CodeLineSelection current,
  ) {
    if (previous != null) {
      var start = _displayOffset(previous.start);
      var end = _displayOffset(previous.end);
      final difference = updated.length - display.length;
      if (previous.isCollapsed && current.isCollapsed && difference < 0) {
        // Backspace and Delete both start from a collapsed selection.
        if (current.extentIndex < previous.extentIndex ||
            (current.extentIndex == previous.extentIndex &&
                current.extentOffset < previous.extentOffset)) {
          start += difference;
        } else {
          end -= difference;
        }
      }
      final insertedLength = difference + end - start;
      if (start >= 0 &&
          end <= display.length &&
          insertedLength >= 0 &&
          start + insertedLength <= updated.length &&
          updated.startsWith(display.substring(0, start)) &&
          updated.endsWith(display.substring(end))) {
        return source.replaceRange(
          _sourceOffset(start),
          _sourceOffset(end),
          updated
              .substring(start, start + insertedLength)
              .replaceAll('\n', newline),
        );
      }
    }
    // Line moves and multi-line indentation may change more than the selection.
    var start = 0;
    final limit = display.length < updated.length
        ? display.length
        : updated.length;
    while (start < limit &&
        display.codeUnitAt(start) == updated.codeUnitAt(start)) {
      start++;
    }
    var oldEnd = display.length, newEnd = updated.length;
    while (oldEnd > start &&
        newEnd > start &&
        display.codeUnitAt(oldEnd - 1) == updated.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    return source.replaceRange(
      _sourceOffset(start),
      _sourceOffset(oldEnd),
      updated.substring(start, newEnd).replaceAll('\n', newline),
    );
  }
}
