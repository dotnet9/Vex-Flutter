import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'code_block.dart';
import 'controller.dart';
import 'reader.dart';

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
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: height / 10,
                                      color: color.onSurfaceVariant,
                                      fontFamily: 'Consolas',
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
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: const ['monospace'],
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
  MarkdownCodeFence? _codeFence;
  MarkdownSnapshot? _checkpoint;
  MarkdownBlockKind _kind = MarkdownBlockKind.paragraph;
  var _start = 0, _end = 0;
  String _prefix = '', _ending = '';
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
    if (!_writing && _checkpoint != null && mounted) {
      setState(() => _checkpoint = null);
    }
  }

  void _begin(MarkdownBlock? block) {
    _finish();
    final source = widget.controller.session.text;
    final raw = block?.range.slice(source) ?? '';
    final marker = block?.kind == MarkdownBlockKind.heading
        ? RegExp(r'^ {0,3}#{1,6}\s+').firstMatch(raw)?.group(0)
        : null;
    _prefix = marker ?? '';
    _ending = RegExp(r'(?:\r\n|\n|\r)$').firstMatch(raw)?.group(0) ?? '';
    _start = block?.range.start ?? source.length;
    _end = block?.range.end ?? source.length;
    _kind = block?.kind ?? MarkdownBlockKind.paragraph;
    _codeFence = _kind == MarkdownBlockKind.code
        ? MarkdownCodeFence.parse(raw)
        : null;
    _language.text = _codeFence?.language ?? '';
    _input.text = _codeFence == null
        ? raw.substring(_prefix.length, raw.length - _ending.length)
        : _codeFence!.code.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    setState(() => _checkpoint = widget.controller.session.snapshot());
    _focus.requestFocus();
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  void _update() {
    if (_checkpoint == null ||
        (_input.value.composing.isValid &&
            !_input.value.composing.isCollapsed) ||
        (_language.value.composing.isValid &&
            !_language.value.composing.isCollapsed)) {
      return;
    }
    final value =
        _codeFence?.replace(code: _input.text, language: _language.text) ??
        '$_prefix${_input.text}$_ending';
    final source = widget.controller.session.text;
    _writing = true;
    try {
      final updated = source.replaceRange(_start, _end, value);
      _end = _start + value.length;
      widget.controller.session.replace(updated, mergeKey: 'instant-$_start');
      widget.controller.select(
        _start +
            (_codeFence?.bodyOffset(
                  code: _input.text,
                  language: _language.text,
                ) ??
                _prefix.length) +
            (_codeFence != null && value.contains('\r\n')
                ? _input.text
                      .substring(
                        0,
                        _input.selection.extentOffset.clamp(
                          0,
                          _input.text.length,
                        ),
                      )
                      .replaceAll('\n', '\r\n')
                      .length
                : _input.selection.extentOffset.clamp(0, _input.text.length)),
      );
    } finally {
      _writing = false;
    }
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
    widget.controller.session.restore(checkpoint);
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
                          style: MarkdownCodeBlock.textStyle(colors, 12),
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
          style: MarkdownCodeBlock.textStyle(colors, widget.compact ? 13 : 14),
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

  Widget _bodyField(ColorScheme colors) => TextField(
    key: const ValueKey('instant-active-input'),
    groupId: this,
    controller: _input,
    focusNode: _focus,
    maxLines: null,
    autocorrect: _codeFence == null,
    enableSuggestions: _codeFence == null,
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    onTapOutside: (_) => _finish(),
    style: _codeFence != null
        ? MarkdownCodeBlock.textStyle(colors, widget.compact ? 13 : 14)
        : TextStyle(
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
                    onTap: () => _begin(block),
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
                      onTap: () => _begin(block),
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
                      if (source.isNotEmpty && !source.endsWith('\n\n')) {
                        widget.controller.session.replace(
                          '$source\n\n',
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
