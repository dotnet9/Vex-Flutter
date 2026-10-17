import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'code_block.dart';
import 'controller.dart';
import 'font_families.dart';
import 'reader.dart';
import 'typing_formatter.dart';

class MarkdownSourceEditor extends StatefulWidget {
  const MarkdownSourceEditor({
    super.key,
    required this.controller,
    this.lineNumbers = true,
    this.fontSize = 14,
  });
  final MarkdownEditorController controller;
  final bool lineNumbers;
  final double fontSize;
  @override
  State<MarkdownSourceEditor> createState() => _MarkdownSourceEditorState();
}

class _MarkdownSourceEditorState extends State<MarkdownSourceEditor> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final height = widget.fontSize * 1.9;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.lineNumbers)
              SizedBox(
                width: 48,
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, _) => OverflowBox(
                      alignment: Alignment.topRight,
                      maxHeight: double.infinity,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          -(_scroll.hasClients ? _scroll.offset : 0.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 26, right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (
                                var i = 0;
                                i <
                                    widget.controller.source.text
                                        .split('\n')
                                        .length;
                                i++
                              )
                                SizedBox(
                                  height: height,
                                  child: Text(
                                    '${i + 1}',
                                    style:
                                        MarkdownCodeBlock.textStyle(
                                          context,
                                          10,
                                        ).copyWith(
                                          fontSize: 10,
                                          height: height / 10,
                                          color: color.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: TextField(
                controller: widget.controller.source,
                focusNode: widget.controller.sourceFocus,
                scrollController: _scroll,
                keyboardType: TextInputType.multiline,
                expands: true,
                minLines: null,
                maxLines: null,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [MarkdownTypingFormatter()],
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                style: MarkdownCodeBlock.textStyle(context, widget.fontSize)
                    .copyWith(
                      fontSize: widget.fontSize,
                      height: 1.9,
                      color: color.onSurface,
                    ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.fromLTRB(
                    widget.lineNumbers ? 4 : 28,
                    26,
                    28,
                    70,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class MarkdownInstantEditor extends StatefulWidget {
  const MarkdownInstantEditor({
    super.key,
    required this.controller,
    this.typography = MarkdownTypography.simple,
    this.compact = false,
    this.fontSize = 15,
    this.padding = const EdgeInsets.fromLTRB(56, 36, 56, 70),
  });
  final MarkdownEditorController controller;
  final MarkdownTypography typography;
  final bool compact;
  final double fontSize;
  final EdgeInsets padding;
  @override
  State<MarkdownInstantEditor> createState() => _MarkdownInstantEditorState();
}

class _MarkdownInstantEditorState extends State<MarkdownInstantEditor> {
  final _input = TextEditingController();
  final _language = TextEditingController();
  final _focus = FocusNode();
  final _languageFocus = FocusNode();
  final _bodyRegion = GlobalKey();
  MarkdownCodeFence? _codeFence;
  MarkdownSnapshot? _checkpoint;
  MarkdownBlockKind _kind = MarkdownBlockKind.paragraph;
  var _start = 0, _end = 0;
  String _prefix = '', _ending = '', _newline = '\n';
  String _lastSource = '';
  var _writing = false;
  @override
  void initState() {
    super.initState();
    _input.addListener(_update);
    _language.addListener(_update);
    widget.controller.session.addListener(_externalChange);
  }

  @override
  void didUpdateWidget(covariant MarkdownInstantEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.session.removeListener(_externalChange);
      widget.controller.session.addListener(_externalChange);
      _checkpoint = null;
    }
  }

  void _externalChange() {
    // Undo, chapter commands and a second editor invalidate this editing range.
    if (!_writing &&
        _checkpoint != null &&
        mounted &&
        widget.controller.session.text != _lastSource) {
      setState(() => _checkpoint = null);
    }
  }

  void _begin(MarkdownBlock? block, {int? sourceOffset, Offset? tapPosition}) {
    _finish();
    final source = widget.controller.session.text;
    final raw = block?.range.slice(source) ?? '';
    final marker = block?.kind == MarkdownBlockKind.heading
        ? RegExp(r'^ {0,3}#{1,6}(?:[ \t]+|$)').firstMatch(raw)?.group(0)
        : null;
    _prefix = marker ?? '';
    _ending = RegExp(r'(?:\r\n|\n|\r)$').firstMatch(raw)?.group(0) ?? '';
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
        _input.selection = TextSelection.fromPosition(
          editable.getPositionForPoint(tapPosition),
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

  void _update() {
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
    _input.dispose();
    _language.dispose();
    _focus.dispose();
    _languageFocus.dispose();
    super.dispose();
  }

  Widget _field(ColorScheme colors) => TextFieldTapRegion(
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
          _cancel();
          return KeyEventResult.handled;
        }
        if ((HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed) &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          _finish();
          return KeyEventResult.handled;
        }
        if (_focus.hasFocus &&
            _input.selection.isCollapsed &&
            !HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isMetaPressed &&
            !HardwareKeyboard.instance.isAltPressed &&
            !HardwareKeyboard.instance.isShiftPressed) {
          final offset = _input.selection.extentOffset;
          final backward =
              event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowUp;
          final forward =
              event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.arrowDown;
          if ((backward && offset == 0 && _moveToBlock(false)) ||
              (forward && offset == _input.text.length && _moveToBlock(true))) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: _codeFence == null
          ? _bodyField(colors)
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarkdownCodeBlock(
                    code: _input.text,
                    fontSize: widget.compact ? 13 : 14,
                    child: _codeBody(colors),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 180,
                      child: Semantics(
                        label: '代码语言',
                        child: TextField(
                          key: const ValueKey('instant-code-language'),
                          groupId: this,
                          controller: _language,
                          focusNode: _languageFocus,
                          onTapOutside: (_) => _finish(),
                          onSubmitted: (_) => _focus.requestFocus(),
                          autocorrect: false,
                          enableSuggestions: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[\s`]')),
                          ],
                          style: MarkdownCodeBlock.textStyle(context, 12),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'text',
                            hintStyle: TextStyle(
                              color: colors.onSurfaceVariant,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: colors.surfaceContainerLow,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(3),
                              borderSide: BorderSide(
                                color: colors.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(3),
                              borderSide: BorderSide(color: colors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );

  Widget _codeBody(ColorScheme colors) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(
          text: _input.text,
          style: MarkdownCodeBlock.textStyle(context, widget.compact ? 13 : 14),
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

  Widget _bodyField(ColorScheme colors) => KeyedSubtree(
    key: _bodyRegion,
    child: TextField(
      key: const ValueKey('instant-active-input'),
      groupId: this,
      controller: _input,
      focusNode: _focus,
      maxLines: null,
      autocorrect: _codeFence == null,
      enableSuggestions: _codeFence == null,
      inputFormatters: [if (_codeFence == null) MarkdownTypingFormatter()],
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      onTapOutside: (_) => _finish(),
      style: _codeFence != null
          ? MarkdownCodeBlock.textStyle(context, widget.compact ? 13 : 14)
          : Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontFamily: widget.typography == MarkdownTypography.book
                  ? MarkdownFontFamilies.of(context).serif
                  : null,
              fontFamilyFallback: widget.typography == MarkdownTypography.book
                  ? MarkdownFontFamilies.of(context).serifFallback
                  : null,
              fontSize: _kind == MarkdownBlockKind.heading
                  ? widget.fontSize * (_prefix.trim() == '#' ? 2 : 1.4)
                  : widget.fontSize,
              height: 1.95,
              color: colors.onSurface,
            ),
      decoration: InputDecoration(
        hintText: _codeFence == null ? '从第一句话开始…' : null,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isCollapsed: true,
        contentPadding: _codeFence == null
            ? const EdgeInsets.symmetric(vertical: 8)
            : EdgeInsets.zero,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final source = widget.controller.session.text;
        final blocks = widget.controller.document.blocks;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.typography.width),
            child: ListView(
              padding: widget.padding,
              children: [
                for (final block in blocks.where(
                  (b) => _checkpoint == null || b.range.end <= _start,
                ))
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        _begin(block, tapPosition: details.globalPosition),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MarkdownReader(
                        data: block.range.slice(source),
                        typography: widget.typography,
                        compact: widget.compact,
                        fontSize: widget.fontSize,
                        selectable: false,
                      ),
                    ),
                  ),
                if (_checkpoint != null) _field(colors),
                if (_checkpoint != null)
                  for (final block in blocks.where(
                    (b) => b.range.start >= _end && b.range.start > _start,
                  ))
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) =>
                          _begin(block, tapPosition: details.globalPosition),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MarkdownReader(
                          data: block.range.slice(source),
                          typography: widget.typography,
                          compact: widget.compact,
                          fontSize: widget.fontSize,
                          selectable: false,
                        ),
                      ),
                    ),
                if (_checkpoint == null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final current = widget.controller.session.text;
                      final newline = widget.controller.document.newline;
                      if (current.isNotEmpty &&
                          !current.endsWith('$newline$newline')) {
                        widget.controller.session.replace(
                          '$current${current.endsWith(newline) ? '' : newline}$newline',
                          label: '新增段落',
                        );
                      }
                      _begin(null);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        blocks.isEmpty ? '从第一句话开始…' : '',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
