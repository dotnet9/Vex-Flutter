import 'document.dart';

final class TextPatch {
  const TextPatch(this.range, this.replacement);
  final SourceRange range;
  final String replacement;
  String apply(String source) {
    RangeError.checkValidRange(range.start, range.end, source.length);
    return source.replaceRange(range.start, range.end, replacement);
  }
}

final class _Edit {
  const _Edit(this.before, this.after, this.label, this.mergeKey, this.time);
  final String before, after, label;
  final String? mergeKey;
  final DateTime time;
}

/// Opaque checkpoint for temporary editing and reversible guided exercises.
final class MarkdownSnapshot {
  MarkdownSnapshot._(
    this._owner,
    this._text,
    this._saved,
    this._undo,
    this._redo,
  );
  final MarkdownSession _owner;
  final String _text, _saved;
  final List<_Edit> _undo, _redo;
}

/// Shared command/history boundary for source, rich editing and chapter actions.
final class MarkdownSession {
  MarkdownSession([String source = ''])
    : this.fromDocument(MarkdownDocument.parse(source));

  MarkdownSession.fromDocument(MarkdownDocument document)
    : _document = document,
      _saved = document.source;
  MarkdownDocument _document;
  String _saved;
  final _undo = <_Edit>[];
  final _redo = <_Edit>[];
  final _listeners = <void Function()>[];
  int _revision = 0;
  int get revision => _revision;
  MarkdownDocument get document => _document;
  String get text => _document.source;
  bool get isDirty => text != _saved;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void addListener(void Function() callback) => _listeners.add(callback);
  void removeListener(void Function() callback) => _listeners.remove(callback);
  void _emit() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void markSaved({String? savedText}) {
    _saved = savedText ?? text;
    _emit();
  }

  MarkdownSnapshot snapshot() =>
      MarkdownSnapshot._(this, text, _saved, List.of(_undo), List.of(_redo));

  /// Editing cancellation keeps the latest disk baseline when a save occurred
  /// after the checkpoint. Guided temporary documents restore the full state.
  void restore(MarkdownSnapshot snapshot, {bool restoreSavedState = true}) {
    if (!identical(snapshot._owner, this)) {
      throw ArgumentError('检查点属于另一个文档会话');
    }
    if (restoreSavedState) _saved = snapshot._saved;
    _undo
      ..clear()
      ..addAll(snapshot._undo);
    _redo
      ..clear()
      ..addAll(snapshot._redo);
    _set(snapshot._text);
  }

  void replace(String value, {String label = '编辑正文', String? mergeKey}) {
    if (value == text) return;
    final now = DateTime.now();
    var before = text;
    if (mergeKey != null &&
        _undo.isNotEmpty &&
        _undo.last.mergeKey == mergeKey &&
        now.difference(_undo.last.time).inMilliseconds < 750) {
      before = _undo.removeLast().before;
    }
    _undo.add(_Edit(before, value, label, mergeKey, now));
    if (_undo.length > 500) _undo.removeAt(0);
    _redo.clear();
    _set(value);
  }

  void patch(TextPatch edit, {String label = '编辑正文', String? mergeKey}) =>
      replace(edit.apply(text), label: label, mergeKey: mergeKey);
  void _set(String value) {
    _document = MarkdownDocument.parse(value);
    _revision++;
    _emit();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final edit = _undo.removeLast();
    _redo.add(edit);
    _set(edit.before);
  }

  void redo() {
    if (_redo.isEmpty) return;
    final edit = _redo.removeLast();
    _undo.add(edit);
    _set(edit.after);
  }

  MarkdownHeading _heading(String id) =>
      document.heading(id) ?? (throw StateError('章节已变更：$id'));

  void renameHeading(String id, String title) {
    if (title.trim().isEmpty || title.contains('\n') || title.contains('\r')) {
      throw ArgumentError.value(title, 'title', '章节标题必须是单行非空文字');
    }
    final heading = _heading(id);
    patch(TextPatch(heading.titleRange, title.trim()), label: '修改章节标题');
  }

  void replaceBody(String id, String body) {
    final heading = _heading(id), nl = document.newline;
    patch(TextPatch(heading.body, '$nl${body.trim()}$nl$nl'), label: '修改章节正文');
  }

  void deleteHeading(String id, {bool keepContents = false}) {
    final heading = _heading(id);
    patch(
      TextPatch(keepContents ? heading.header : heading.section, ''),
      label: '删除章节',
    );
  }

  void addHeading(String? id, {required bool child, String title = '新章节'}) {
    final heading = id == null ? null : _heading(id);
    final level = heading == null ? 1 : heading.level + (child ? 1 : 0);
    if (level > 6) throw StateError('最多支持六级标题');
    final offset = child
        ? heading?.body.end ?? text.length
        : heading?.section.end ?? text.length;
    final nl = document.newline;
    final prefix = offset > 0 && !text.substring(0, offset).endsWith('$nl$nl')
        ? nl
        : '';
    patch(
      TextPatch(
        SourceRange(offset, offset),
        '$prefix${'#' * level} $title$nl$nl',
      ),
      label: '新增章节',
    );
  }

  List<MarkdownHeading> _subtree(MarkdownHeading heading) => document.headings
      .where(
        (h) =>
            h.header.start >= heading.header.start &&
            h.header.start < heading.section.end,
      )
      .toList();
  String _shift(MarkdownHeading heading, int delta) {
    final nodes = _subtree(heading);
    if (nodes.any((h) => h.level + delta < 1 || h.level + delta > 6)) {
      throw StateError('调整后标题级别必须在一至六级之间');
    }
    var section = heading.section.slice(text);
    for (final h in nodes.reversed) {
      final raw = h.header.slice(text);
      final nl = raw.endsWith('\r\n')
          ? '\r\n'
          : raw.endsWith('\n')
          ? '\n'
          : '';
      final replacement = '${'#' * (h.level + delta)} ${h.title}$nl';
      section = section.replaceRange(
        h.header.start - heading.header.start,
        h.header.end - heading.header.start,
        replacement,
      );
    }
    return section;
  }

  void changeLevel(String id, int delta) {
    final heading = _heading(id);
    patch(
      TextPatch(heading.section, _shift(heading, delta)),
      label: delta < 0 ? '提升章节' : '降低章节',
    );
  }

  void moveHeading(String id, int direction) {
    final heading = _heading(id);
    final siblings = document.headings
        .where((h) => h.parentId == heading.parentId)
        .toList();
    final index = siblings.indexWhere((h) => h.id == id),
        targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= siblings.length) return;
    final target = siblings[targetIndex];
    _move(
      heading,
      direction < 0 ? target.header.start : target.section.end,
      heading.section.slice(text),
    );
  }

  void reparentHeading(String id, String parentId) {
    final heading = _heading(id), parent = _heading(parentId);
    if (heading.section.contains(parent.header.start)) {
      throw StateError('不能把章节移动到自己的子章节');
    }
    _move(
      heading,
      parent.section.end,
      _shift(heading, parent.level + 1 - heading.level),
    );
  }

  void _move(MarkdownHeading heading, int target, String content) {
    var remaining = text.replaceRange(
      heading.section.start,
      heading.section.end,
      '',
    );
    if (target > heading.section.start) target -= heading.section.length;
    final nl = document.newline;
    if (target > 0 && !remaining.substring(0, target).endsWith(nl)) {
      content = '$nl$content';
    }
    if (target < remaining.length && !content.endsWith(nl)) {
      content = '$content$nl';
    }
    remaining = remaining.replaceRange(target, target, content);
    replace(remaining, label: '移动章节');
  }
}
