import 'dart:async';

import 'package:flutter/cupertino.dart' show cupertinoTextSelectionControls;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

import 'code_block.dart';
import 'code_highlighting.dart';
import 'context_request.dart';
import 'context_shortcuts.dart';
import 'controller.dart';
import 'editing_preferences.dart';
import 'element_target.dart';
import 'inline_editing_controller.dart';
import 'labels.dart';
import 'list_navigation.dart';
import 'markdown_preferences.dart';
import 'mermaid_block.dart';
import 'reader.dart';
import 'selection_geometry.dart';
import 'table_editor.dart';
import 'typing_formatter.dart';

export 'source_editor.dart';

part 'editor_selection.dart';
part 'editor_touch_selection.dart';

class MarkdownInstantEditor extends StatefulWidget {
  const MarkdownInstantEditor({
    super.key,
    required this.controller,
    this.typography = MarkdownTypography.simple,
    this.compact = false,
    this.fontSize = 15,
    this.padding = const EdgeInsets.fromLTRB(56, 36, 56, 70),
    this.labels = const MarkdownEditorLabels(),
    this.imageBuilder,
    this.typewriter = false,
    this.focusMode = false,
    this.editingPreferences,
    this.preferences = const MarkdownPreferences(),
    this.onContextMenu,
  });
  final MarkdownEditorLabels labels;
  final MarkdownEditorController controller;
  final MarkdownTypography typography;
  final bool compact;
  final double fontSize;
  final EdgeInsets padding;
  final Widget Function(Uri uri, String? title, String? alt)? imageBuilder;
  final bool typewriter, focusMode;
  final MarkdownEditingPreferences? editingPreferences;
  final MarkdownPreferences preferences;
  final ValueChanged<MarkdownContextRequest>? onContextMenu;
  @override
  State<MarkdownInstantEditor> createState() => _MarkdownInstantEditorState();
}

class _MarkdownInstantEditorState extends State<MarkdownInstantEditor>
    with SingleTickerProviderStateMixin {
  final _input = MarkdownInlineEditingController();
  final _language = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: (_, event) => _inputKey(event));
  final _languageFocus = FocusNode();
  final _bodyRegion = GlobalKey();
  final _viewportRegion = GlobalKey();
  final _scroll = ScrollController();
  final _list = ListController();
  double _minimumActiveHeight = 0;
  late final _navigation = MarkdownListNavigator(
    vsync: this,
    list: _list,
    scroll: _scroll,
  );
  bool _centerScheduled = false;
  MarkdownDocument? _indexedDocument;
  int? _indexedStart, _indexedEnd;
  List<MarkdownBlock> _visibleBlocks = const [];
  Map<Key, int> _blockIndices = const {};
  MarkdownCodeFence? _codeFence;
  MarkdownSnapshot? _checkpoint;
  MarkdownBlockKind _kind = MarkdownBlockKind.paragraph;
  var _start = 0, _end = 0;
  String _prefix = '', _ending = '', _newline = '\n';
  String _lastSource = '';
  var _writing = false;
  Offset? _dragOrigin;
  int? _dragBase;
  int? _dragSourceBase, _dragBlockStart, _dragPointer;
  Offset? _dragPosition;
  Timer? _dragScrollTimer;
  final _selectionGeometries = <int, MarkdownSelectionGeometry>{};
  final _selectionInput = TextEditingController();
  final _selectionFocus = FocusNode();
  bool _documentSelection = false, _selectionSync = false;
  String _selectedOriginal = '';
  int _selectionRevision = -1;
  Offset _selectionAnchor = Offset.zero;
  PointerDeviceKind? _lastPointerKind;
  bool _touchSelection = false, _touchToolbar = false, _touchKeyboard = false;
  bool? _touchHandleStart;
  Offset _touchHandleDelta = Offset.zero;

  void _rebuildSelection(VoidCallback update) => setState(update);

  void _indexBlocks() {
    final document = widget.controller.document;
    final start = _checkpoint == null ? null : _start;
    final end = _checkpoint == null ? null : _end;
    if (identical(_indexedDocument, document) &&
        _indexedStart == start &&
        _indexedEnd == end) {
      return;
    }
    _indexedDocument = document;
    _indexedStart = start;
    _indexedEnd = end;
    _visibleBlocks = start == null
        ? document.blocks
        : [
            for (final block in document.blocks)
              if (block.range.end <= start) block,
            MarkdownBlock(_kind, SourceRange(start, end!), 1),
            for (final block in document.blocks)
              if (block.range.start >= end && block.range.start > start) block,
          ];
    _blockIndices = {
      for (var i = 0; i < _visibleBlocks.length; i++)
        ValueKey(_visibleBlocks[i].range.start): i,
    };
    _selectionGeometries.removeWhere(
      (start, _) =>
          start != _start && !_blockIndices.containsKey(ValueKey(start)),
    );
  }

  void _editAt(int offset) {
    if (!mounted) return;
    final at = offset.clamp(0, widget.controller.text.length);
    final block =
        widget.controller.document.blocks
            .where((b) => b.range.contains(at))
            .firstOrNull ??
        widget.controller.document.blocks
            .where((b) => b.range.end == at)
            .lastOrNull ??
        MarkdownBlock(MarkdownBlockKind.paragraph, SourceRange(at, at), 1);
    _begin(block, sourceOffset: at);
  }

  void _openBlockContext(MarkdownBlock block, Offset position) {
    if (widget.onContextMenu == null) return;
    _finish();
    final source = widget.controller.text;
    final media =
        const [
          MarkdownBlockKind.code,
          MarkdownBlockKind.math,
        ].contains(block.kind)
        ? <MarkdownMediaTarget>[]
        : markdownMediaTargets(source, block);
    final selection = widget.controller.selection;
    final selectedHere =
        selection.isValid &&
        !selection.isCollapsed &&
        selection.start < block.range.end &&
        selection.end > block.range.start;
    widget.onContextMenu!(
      MarkdownContextRequest(
        offset: selectedHere
            ? selection.start
            : media.length == 1
            ? media.single.range.start
            : block.range.start,
        position: position,
        selection: selectedHere
            ? selection
            : TextSelection.collapsed(offset: block.range.start),
        onEdit: () => _begin(block),
        onEditAt: _editAt,
      ),
    );
  }

  void _openMediaContext(
    MarkdownBlock block,
    String url,
    bool image,
    int occurrence,
    Offset position,
  ) {
    final token = markdownMediaTargets(widget.controller.text, block)
        .where(
          (token) =>
              token.image == image && token.url == markdownAttributeText(url),
        )
        .elementAtOrNull(occurrence);
    if (token == null) return;
    _finish();
    widget.onContextMenu?.call(
      MarkdownContextRequest(
        offset: token.range.start,
        position: position,
        selection: TextSelection.collapsed(offset: token.range.start),
        onEditAt: _editAt,
      ),
    );
  }

  Widget _contextBlock(MarkdownBlock block, String source) {
    final child = _selectionBlock(block, source, _displayBlock(block, source));
    if (block.kind == MarkdownBlockKind.table) {
      return child;
    }
    return GestureDetector(
      key: ValueKey('element-block-${block.range.start}'),
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (event) =>
          _openBlockContext(block, event.globalPosition),
      onLongPressStart: (event) {
        if (_lastPointerKind == PointerDeviceKind.mouse ||
            (widget.onContextMenu != null &&
                !(_geometryAt(event.globalPosition)
                        ?.containsText(event.globalPosition) ??
                    false))) {
          _openBlockContext(block, event.globalPosition);
        } else {
          _startTouchSelection(event.globalPosition);
        }
      },
      onLongPressMoveUpdate: (event) =>
          _moveTouchSelection(event.globalPosition),
      onLongPressEnd: (_) => _endTouchSelectionDrag(),
      child: child,
    );
  }

  void _dragSelection(PointerMoveEvent event) {
    _moveDocumentDrag(event);
  }

  Widget _displayBlock(MarkdownBlock block, String source) {
    if (block.kind == MarkdownBlockKind.math) {
      return _mathBlock(block.range.slice(source), block: block);
    }
    if (block.kind == MarkdownBlockKind.code) {
      final fence = MarkdownCodeFence.parse(block.range.slice(source));
      if (widget.preferences.mermaid &&
          fence?.language.toLowerCase() == 'mermaid') {
        return MarkdownMermaidBlock(
          key: ValueKey('diagram-${block.range.start}'),
          source: fence!.code,
          labels: widget.labels,
          onEdit: () => _begin(block),
          tapGroup: this,
        );
      }
    }
    if (block.kind == MarkdownBlockKind.table) {
      return MarkdownTableEditor(
        key: ValueKey('table-${block.range.start}'),
        controller: widget.controller,
        start: block.range.start,
        end: block.range.end,
        style: _reader.styleSheet(context).p!,
        onContextMenu: widget.onContextMenu,
        onTouchSelection: _touchContextRequest,
        onSelectionChanged: (selection) {
          if (!_documentSelection) {
            widget.controller.select(
              selection.baseOffset,
              selection.extentOffset,
            );
          }
        },
        preferences: widget.preferences,
        editingPreferences: widget.editingPreferences,
        imageBuilder: widget.imageBuilder,
        labels: widget.labels,
      );
    }
    return AnimatedOpacity(
      opacity: widget.focusMode && _checkpoint != null ? .32 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      child: Listener(
        onPointerDown: (event) {
          if (event.kind != PointerDeviceKind.mouse ||
              (event.buttons & kPrimaryMouseButton) == 0) {
            return;
          }
          if (!HardwareKeyboard.instance.isShiftPressed) {
            _begin(block, tapPosition: event.position);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (!HardwareKeyboard.instance.isShiftPressed) {
              _begin(block, tapPosition: details.globalPosition);
            }
          },
          child: MarkdownReader(
            data: block.range.slice(source),
            documentSource: source,
            document: widget.controller.document,
            typography: widget.typography,
            compact: widget.compact,
            fontSize: widget.fontSize,
            selectable: false,
            imageBuilder: widget.imageBuilder,
            onMediaContext: widget.onContextMenu == null
                ? null
                : (url, image, occurrence, position) => _openMediaContext(
                    block,
                    url,
                    image,
                    occurrence,
                    position,
                  ),
            editingPreferences: widget.editingPreferences,
            preferences: widget.preferences,
            labels: widget.labels,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _input.addListener(_update);
    _language.addListener(_update);
    _focus.addListener(_scheduleCenter);
    _selectionInput.addListener(_selectionBufferChanged);
    widget.controller.source.addListener(_observeDocumentSelection);
    widget.controller.session.addListener(_externalChange);
    widget.controller.navigation.addListener(_revealNavigation);
    _revealNavigation();
  }

  @override
  void didUpdateWidget(covariant MarkdownInstantEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.session.removeListener(_externalChange);
      oldWidget.controller.navigation.removeListener(_revealNavigation);
      oldWidget.controller.source.removeListener(_observeDocumentSelection);
      widget.controller.session.addListener(_externalChange);
      widget.controller.navigation.addListener(_revealNavigation);
      widget.controller.source.addListener(_observeDocumentSelection);
      _clearDocumentSelection();
      _selectionGeometries.clear();
      _checkpoint = null;
      _revealNavigation();
    }
    if (oldWidget.typewriter != widget.typewriter) _scheduleCenter();
  }

  void _scheduleCenter() {
    if (!widget.typewriter ||
        _centerScheduled ||
        !_focus.hasFocus ||
        _dragOrigin != null) {
      return;
    }
    _centerScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerScheduled = false;
      if (!mounted ||
          !widget.typewriter ||
          !_focus.hasFocus ||
          !_scroll.hasClients ||
          _checkpoint == null) {
        return;
      }
      final editable = _editable();
      final viewport =
          _viewportRegion.currentContext?.findRenderObject() as RenderBox?;
      if (editable == null || viewport == null || !_input.selection.isValid) {
        return;
      }
      final caret = editable.getLocalRectForCaret(_input.selection.extent);
      final center = viewport
          .globalToLocal(editable.localToGlobal(caret.center))
          .dy;
      final position = _scroll.position;
      final target = (_scroll.offset + center - viewport.size.height / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((target - _scroll.offset).abs() > .5) _scroll.jumpTo(target);
    });
  }

  void _revealNavigation() {
    final controller = widget.controller;
    final request = controller.navigation.value;
    if (request == null) {
      _navigation.cancel();
      return;
    }
    if (_checkpoint != null) {
      _finish();
      controller.select(
        request.selection.baseOffset,
        request.selection.extentOffset,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.controller != controller ||
          controller.navigation.value != request ||
          !_list.isAttached ||
          !_scroll.hasClients) {
        return;
      }
      final blocks = controller.document.blocks;
      if (blocks.isEmpty) return;
      final index = blocks.indexWhere(
        (b) => b.range.end > request.selection.start,
      );
      final target = index < 0 ? blocks.length - 1 : index;
      _navigation.reveal(target);
    });
  }

  void _externalChange() {
    if (!_writing &&
        _documentSelection &&
        _selectionRevision != widget.controller.session.revision) {
      _clearDocumentSelection();
    }
    // Undo, chapter commands and a second editor invalidate this editing range.
    if (!_writing &&
        _checkpoint != null &&
        mounted &&
        widget.controller.session.text != _lastSource) {
      setState(() => _checkpoint = null);
    }
  }

  void _begin(MarkdownBlock? block, {int? sourceOffset, Offset? tapPosition}) {
    _clearDocumentSelection();
    _finish();
    final source = widget.controller.session.text;
    _minimumActiveHeight = block == null
        ? 0
        : _selectionGeometries[block.range.start]?.box?.size.height ?? 0;
    final raw = block?.range.slice(source) ?? '';
    final marker = block?.kind == MarkdownBlockKind.heading
        ? RegExp(r'^ {0,3}#{1,6}(?:[ \t]+|$)').firstMatch(raw)?.group(0)
        : null;
    _prefix = marker ?? '';
    _ending = RegExp(r'(?:\r\n|\n|\r)+$').firstMatch(raw)?.group(0) ?? '';
    _newline =
        RegExp(r'\r\n|\n|\r').firstMatch(raw)?.group(0) ??
        widget.controller.document.newline;
    _lastSource = source;
    _start = block?.range.start ?? source.length;
    _end = block?.range.end ?? source.length;
    _kind = block?.kind ?? MarkdownBlockKind.paragraph;
    _codeFence = _kind == MarkdownBlockKind.code
        ? MarkdownCodeFence.parse(raw)
        : null;
    _language.text = _codeFence?.language ?? '';
    final body = _codeFence == null
        ? raw.substring(_prefix.length, raw.length - _ending.length)
        : _codeFence!.code;
    _input.text = body.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    setState(() => _checkpoint = widget.controller.session.snapshot());
    _focus.requestFocus();
    final bodyStart = _start + (_codeFence?.bodyOffset() ?? _prefix.length);
    final localOffset = sourceOffset == null
        ? _input.text.length
        : source
              .substring(
                bodyStart,
                sourceOffset.clamp(bodyStart, bodyStart + body.length),
              )
              .replaceAll('\r\n', '\n')
              .replaceAll('\r', '\n')
              .length;
    _input.selection = TextSelection.collapsed(offset: localOffset);
    if (tapPosition != null) {
      final checkpoint = _checkpoint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _checkpoint != checkpoint) return;
        final editable = _editable();
        if (editable == null) return;
        final localPosition = editable.globalToLocal(tapPosition);
        _input.selection = TextSelection.fromPosition(
          editable.getPositionForPoint(localPosition),
        );
      });
    }
  }

  RenderEditable? _editable() {
    RenderEditable? result;
    void visit(RenderObject object) {
      if (object is RenderEditable) {
        result = object;
      } else if (result == null) {
        object.visitChildren(visit);
      }
    }

    final root = _bodyRegion.currentContext?.findRenderObject();
    if (root != null) visit(root);
    return result;
  }

  bool _showKeyboardContext() {
    if (widget.onContextMenu == null ||
        !_focus.hasFocus ||
        !_input.value.composing.isCollapsed) {
      return false;
    }
    final body = _bodyRegion.currentContext;
    final position = body == null ? null : markdownCaretMenuPosition(body);
    if (position == null) return false;
    final selection = widget.controller.selection;
    widget.onContextMenu!(
      MarkdownContextRequest(
        offset: selection.isValid ? selection.start : _start,
        selection: selection,
        position: position,
        keyboard: true,
        onEdit: () => _focus.requestFocus(),
        onEditAt: _editAt,
      ),
    );
    return true;
  }

  void _update() {
    _scheduleCenter();
    if (_checkpoint == null ||
        (_input.value.composing.isValid &&
            !_input.value.composing.isCollapsed) ||
        (_language.value.composing.isValid &&
            !_language.value.composing.isCollapsed)) {
      return;
    }
    if (_kind == MarkdownBlockKind.heading &&
        _prefix.isNotEmpty &&
        _input.text.contains('\n')) {
      _splitHeading();
      return;
    }
    final value =
        _codeFence?.replace(code: _input.text, language: _language.text) ??
        '$_prefix${_input.text.replaceAll('\n', _newline)}$_ending';
    final source = widget.controller.session.text;
    _writing = true;
    try {
      final updated = source.replaceRange(_start, _end, value);
      _end = _start + value.length;
      _lastSource = updated;
      widget.controller.session.replace(updated, mergeKey: 'instant-$_start');
      final bodyStart =
          _start +
          (_codeFence?.bodyOffset(
                code: _input.text,
                language: _language.text,
              ) ??
              _prefix.length);
      int map(int offset) =>
          bodyStart +
          _input.text
              .substring(0, offset.clamp(0, _input.text.length))
              .replaceAll('\n', _newline)
              .length;
      widget.controller.select(
        map(_input.selection.baseOffset),
        map(_input.selection.extentOffset),
      );
    } finally {
      _writing = false;
    }
  }

  void _splitHeading() {
    final text = _input.text;
    final split = text.indexOf('\n');
    final value =
        '$_prefix${text.substring(0, split)}$_newline$_newline'
        '${text.substring(split + 1).replaceAll('\n', _newline)}$_ending';
    final paragraphStart =
        _start + _prefix.length + split + 2 * _newline.length;
    final cursor = _input.selection.extentOffset.clamp(split + 1, text.length);
    final offset =
        paragraphStart +
        text.substring(split + 1, cursor).replaceAll('\n', _newline).length;
    // The inserted paragraph has its own style and editing checkpoint.
    _checkpoint = null;
    widget.controller.session.replace(
      widget.controller.session.text.replaceRange(_start, _end, value),
      label: '标题后新增段落',
    );
    final block =
        widget.controller.document.blocks
            .where(
              (block) =>
                  block.range.start >= paragraphStart &&
                  block.range.start <= offset &&
                  offset <= block.range.end,
            )
            .firstOrNull ??
        MarkdownBlock(
          MarkdownBlockKind.paragraph,
          SourceRange(paragraphStart, paragraphStart),
          1,
        );
    _begin(block, sourceOffset: offset);
  }

  bool _moveToBlock(bool forward) {
    final blocks = widget.controller.document.blocks;
    final target = forward
        ? blocks
              .where((b) => b.range.start >= _end && b.range.start > _start)
              .firstOrNull
        : blocks.where((b) => b.range.end <= _start).lastOrNull;
    if (target == null) return false;
    _begin(
      target,
      sourceOffset: forward ? target.range.start : target.range.end,
    );
    return true;
  }

  void _finish() {
    if (_checkpoint == null) return;
    _input.value = _input.value.copyWith(composing: TextRange.empty);
    _language.value = _language.value.copyWith(composing: TextRange.empty);
    _update();
    setState(() => _checkpoint = null);
    _focus.unfocus();
    _languageFocus.unfocus();
  }

  void _cancel() {
    final checkpoint = _checkpoint;
    if (checkpoint == null) return;
    _checkpoint = null;
    widget.controller.session.restore(checkpoint, restoreSavedState: false);
    _focus.unfocus();
    _languageFocus.unfocus();
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.session.removeListener(_externalChange);
    widget.controller.navigation.removeListener(_revealNavigation);
    widget.controller.source.removeListener(_observeDocumentSelection);
    _dragScrollTimer?.cancel();
    _selectionInput.dispose();
    _selectionFocus.dispose();
    _navigation.dispose();
    _input.dispose();
    _language.dispose();
    _focus.dispose();
    _languageFocus.dispose();
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  bool get _isMermaid =>
      widget.preferences.mermaid &&
      _codeFence != null &&
      _language.text.toLowerCase() == 'mermaid';

  Widget _field(ColorScheme colors) {
    if (_kind == MarkdownBlockKind.math) {
      return _mathBlock(_input.text, editing: true);
    }
    if (!_isMermaid) return _fieldRegion(colors);
    return MarkdownMermaidBlock(
      key: ValueKey('diagram-$_start'),
      source: _input.text,
      labels: widget.labels,
      tapGroup: this,
      composing:
          _input.value.composing.isValid && !_input.value.composing.isCollapsed,
      sourceEditor: _fieldRegion(colors),
    );
  }

  Widget _mathBlock(
    String source, {
    MarkdownBlock? block,
    bool editing = false,
  }) => TextFieldTapRegion(
    key: ValueKey('formula-${block?.range.start ?? _start}'),
    groupId: this,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (context) {
            final input = editing
                ? Container(
                    constraints: const BoxConstraints(
                      minHeight: 80,
                      maxHeight: 360,
                    ),
                    padding: const EdgeInsets.all(14),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: _fieldRegion(Theme.of(context).colorScheme),
                  )
                : const SizedBox(width: double.infinity);
            if (MediaQuery.disableAnimationsOf(context)) return input;
            return AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: input,
            );
          },
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: editing ? null : () => _begin(block),
          child: MarkdownReader(
            data: source,
            documentSource: widget.controller.session.text,
            typography: widget.typography,
            fontSize: widget.fontSize,
            compact: widget.compact,
            preferences: widget.preferences,
            selectable: false,
          ),
        ),
      ],
    ),
  );

  KeyEventResult _inputKey(KeyEvent event) {
    if (!_input.value.composing.isCollapsed ||
        event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_input.selection.isCollapsed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey, offset = _input.selection.extentOffset;
    final backward =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp;
    final forward =
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown;
    final editable = _editable();
    final caret = editable?.getLocalRectForCaret(_input.selection.extent);
    final firstLine =
        caret != null && caret.top < editable!.preferredLineHeight;
    final lastLine =
        caret != null &&
        caret.bottom > editable!.size.height - editable.preferredLineHeight;
    if ((backward &&
            (offset == 0 || key == LogicalKeyboardKey.arrowUp && firstLine) &&
            _moveToBlock(false)) ||
        (forward &&
            (offset == _input.text.length ||
                key == LogicalKeyboardKey.arrowDown && lastLine) &&
            _moveToBlock(true))) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _fieldRegion(ColorScheme colors) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: _minimumActiveHeight),
    child: TextFieldTapRegion(
      groupId: this,
      child: Focus(
        onKeyEvent: (_, event) {
          if ((_input.value.composing.isValid &&
                  !_input.value.composing.isCollapsed) ||
              (_language.value.composing.isValid &&
                  !_language.value.composing.isCollapsed)) {
            return KeyEventResult.ignored;
          }
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _isMermaid || _kind == MarkdownBlockKind.math
                ? _finish()
                : _cancel();
            return KeyEventResult.handled;
          }
          if ((HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed) &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            _finish();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: _isMermaid
            ? _codeBody(colors)
            : _codeFence == null
            ? _proseField(colors)
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: MarkdownCodeBlock(
                  code: _input.text,
                  fontSize: _codeFontSize,
                  footer: SizedBox(
                    width: 180,
                    height: 26,
                    child: _languageField(colors),
                  ),
                  child: _codeBody(colors),
                ),
              ),
      ),
    ),
  );

  Widget _languageField(ColorScheme colors) => Semantics(
    label: widget.labels.codeLanguage,
    child: RawAutocomplete<String>(
      textEditingController: _language,
      focusNode: _languageFocus,
      optionsViewOpenDirection: OptionsViewOpenDirection.up,
      optionsBuilder: (value) {
        return MarkdownCodeHighlighting.matching(value.text);
      },
      onSelected: (_) => _focus.requestFocus(),
      optionsViewBuilder: (context, select, options) => Align(
        alignment: Alignment.bottomRight,
        child: TextFieldTapRegion(
          groupId: this,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              width: 180,
              height: (options.length * 36.0).clamp(36, 216),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemExtent: 36,
                itemBuilder: (context, index) {
                  final name = options.elementAt(index);
                  return InkWell(
                    onTap: () => select(name),
                    child: ColoredBox(
                      color: AutocompleteHighlightedOption.of(context) == index
                          ? colors.primary.withValues(alpha: .12)
                          : Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            MarkdownCodeHighlighting.label(name),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      fieldViewBuilder: (context, controller, focus, submit) => TextField(
        key: const ValueKey('instant-code-language'),
        groupId: this,
        controller: _language,
        focusNode: _languageFocus,
        onTapOutside: (_) => _finish(),
        onSubmitted: (_) => submit(),
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\s`]'))],
        style: MarkdownCodeBlock.textStyle(context, 12),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'text',
          hintStyle: TextStyle(color: colors.onSurfaceVariant),
          isDense: true,
          filled: true,
          fillColor: colors.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
      ),
    ),
  );

  MarkdownReader get _reader => MarkdownReader(
    data: '',
    typography: widget.typography,
    compact: widget.compact,
    fontSize: widget.fontSize,
    editingPreferences: widget.editingPreferences,
    preferences: widget.preferences,
  );
  int get _level => _prefix.trim().length.clamp(1, 6);
  double get _codeFontSize =>
      widget.editingPreferences?.codeSize ??
      widget.fontSize / 15 * (widget.compact ? 13 : 14);
  TextStyle get _activeStyle {
    final sheet = _reader.styleSheet(context);
    if (_kind != MarkdownBlockKind.heading) return sheet.p!;
    return switch (_level) {
      1 => sheet.h1!,
      2 => sheet.h2!,
      3 => sheet.h3!,
      4 => sheet.h4!,
      5 => sheet.h5!,
      _ => sheet.h6!,
    };
  }

  Widget _proseField(ColorScheme colors) => _kind == MarkdownBlockKind.heading
      ? MarkdownHeadingFrame(
          typography: widget.typography,
          compact: widget.compact,
          level: _level,
          style: _activeStyle,
          child: _bodyField(colors),
        )
      : Padding(
          padding: EdgeInsets.only(
            bottom: _kind == MarkdownBlockKind.list
                ? 0
                : _reader.styleSheet(context).pPadding!.bottom,
          ),
          child: _bodyField(colors),
        );

  Widget _codeBody(ColorScheme colors) => LayoutBuilder(
    builder: (context, constraints) {
      if (widget.editingPreferences?.codeWrap == true) {
        return _bodyField(colors);
      }
      final painter = TextPainter(
        text: TextSpan(
          text: _input.text,
          style: MarkdownCodeBlock.textStyle(context, _codeFontSize),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width + 4;
      painter.dispose();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width > constraints.maxWidth ? width : constraints.maxWidth,
          child: _bodyField(colors),
        ),
      );
    },
  );

  Widget _bodyField(ColorScheme colors) {
    _input.presentationEnabled =
        _codeFence == null && _kind != MarkdownBlockKind.math;
    _input.preferences = widget.preferences;
    _input.codeLanguage = _codeFence == null ? null : _language.text;
    return KeyedSubtree(
      key: _bodyRegion,
      child: MarkdownContextShortcuts(
        onShow: widget.onContextMenu == null ? null : _showKeyboardContext,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyA, control: true):
                _selectWholeDocument,
            const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
                _selectWholeDocument,
            const SingleActivator(LogicalKeyboardKey.tab): () =>
                indentMarkdownSelection(
                  _input,
                  widget.editingPreferences?.indent ?? 2,
                ),
            const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
                indentMarkdownSelection(
                  _input,
                  widget.editingPreferences?.indent ?? 2,
                  reverse: true,
                ),
          },
          child: TextField(
            key: const ValueKey('instant-active-input'),
            groupId: this,
            controller: _input,
            focusNode: _focus,
            contextMenuBuilder: (context, editable) {
              if ((!_isTouchPointer ||
                      editable.textEditingValue.selection.isCollapsed) &&
                  widget.onContextMenu == null) {
                return AdaptiveTextSelectionToolbar.editableText(
                  editableTextState: editable,
                );
              }
              final position = editable.contextMenuAnchors.primaryAnchor;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                editable.hideToolbar();
                final selection = widget.controller.selection;
                _touchContextRequest(
                  MarkdownContextRequest(
                    offset: selection.isValid ? selection.start : _start,
                    selection: selection,
                    position: position,
                    onEdit: () => _focus.requestFocus(),
                    onEditAt: _editAt,
                  ),
                );
              });
              return const SizedBox.shrink();
            },
            maxLines: null,
            autocorrect: _codeFence == null,
            enableSuggestions: _codeFence == null,
            inputFormatters: [
              if (widget.editingPreferences?.autoPair == true)
                const MarkdownPairFormatter(),
              if (_codeFence == null) MarkdownTypingFormatter(),
            ],
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            onTapOutside: (_) => _finish(),
            style: _codeFence != null
                ? MarkdownCodeBlock.textStyle(context, _codeFontSize)
                : _activeStyle,
            strutStyle: _codeFence == null
                ? null
                : StrutStyle.fromTextStyle(
                    MarkdownCodeBlock.textStyle(context, _codeFontSize),
                    forceStrutHeight: true,
                  ),
            textAlign:
                _kind == MarkdownBlockKind.heading && widget.typography.centered
                ? TextAlign.center
                : TextAlign.start,
            scrollPadding: EdgeInsets.zero,
            cursorHeight: _codeFence == null ? _activeStyle.fontSize : null,

            decoration: InputDecoration(
              hintText: _codeFence == null && _input.text.isEmpty
                  ? widget.labels.placeholder
                  : null,
              maintainHintSize: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final source = widget.controller.session.text;
        final blocks = widget.controller.document.blocks;
        _indexBlocks();
        final visibleBlocks = _visibleBlocks;
        return Stack(
          children: [
            Listener(
              onPointerDown: _documentPointerDown,
              onPointerSignal: (_) => _navigation.cancel(),
              onPointerMove: _dragSelection,
              onPointerUp: (_) => _endDocumentDrag(),
              onPointerCancel: (_) => _endDocumentDrag(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _navigation.preservePosition((
                    constraints.biggest,
                    widget.typography,
                    widget.compact,
                    widget.fontSize,
                    widget.editingPreferences,
                    widget.preferences,
                    MediaQuery.textScalerOf(context),
                  ), contentKey: widget.controller.document);
                  return Align(
                    key: _viewportRegion,
                    alignment: Alignment.topCenter,
                    // 正文随内容区铺满（Typora 参照）：即时编辑不再按排版
                    // 主题限制居中栏宽，导出仍保留每主题栏宽。
                    child: SuperListView.builder(
                      key: PageStorageKey(widget.controller),
                      controller: _scroll,
                      listController: _list,
                      cacheExtent: constraints.maxHeight,
                      padding: widget.padding.copyWith(
                        top: widget.typewriter
                            ? constraints.maxHeight / 2
                            : widget.padding.top,
                        bottom: widget.typewriter
                            ? constraints.maxHeight / 2
                            : widget.padding.bottom,
                      ),
                      itemCount:
                          visibleBlocks.length + (_checkpoint == null ? 1 : 0),
                      findChildIndexCallback: (key) =>
                          key == const ValueKey('instant-new-paragraph')
                          ? (_checkpoint == null ? visibleBlocks.length : null)
                          : _blockIndices[key],
                      itemBuilder: (context, index) {
                        if (index < visibleBlocks.length) {
                          final block = visibleBlocks[index];
                          return KeyedSubtree(
                            key: ValueKey(block.range.start),
                            child:
                                _checkpoint != null &&
                                    block.range.start == _start
                                ? _selectionBlock(
                                    block,
                                    source,
                                    _field(colors),
                                    active: true,
                                  )
                                : _contextBlock(block, source),
                          );
                        }
                        return GestureDetector(
                          key: const ValueKey('instant-new-paragraph'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            final current = widget.controller.session.text;
                            final newline = widget.controller.document.newline;
                            if (current.isNotEmpty &&
                                !current.endsWith('$newline$newline')) {
                              widget.controller.session.replace(
                                '$current${current.endsWith(newline) ? '' : newline}$newline',
                                label: widget.labels.newParagraph,
                              );
                            }
                            _begin(null);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              blocks.isEmpty ? widget.labels.placeholder : '',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (_documentSelection) _documentSelectionInput(colors),
            if (_documentSelection && _touchSelection)
              Positioned.fill(
                child: _MarkdownTouchSelectionOverlay(
                  selection: widget.controller.selection,
                  sourceLength: source.length,
                  geometries: _selectionGeometries,
                  scroll: _scroll,
                  toolbar: _touchToolbar,
                  onHandleStart: _startTouchHandle,
                  onHandleUpdate: _moveTouchHandle,
                  onHandleEnd: _endTouchSelectionDrag,
                  onCopy: () => unawaited(_selectionCopy()),
                  onCut: () => unawaited(_selectionCopy(cut: true)),
                  onPaste: () => unawaited(_selectionPaste()),
                  onSelectAll: _selectWholeDocument,
                  onMore: widget.onContextMenu == null
                      ? null
                      : _showTouchSelectionContext,
                ),
              ),
          ],
        );
      },
    );
  }
}
