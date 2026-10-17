import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import 'code_block.dart';
import 'context_request.dart';
import 'context_shortcuts.dart';
import 'controller.dart';
import 'editing_preferences.dart';
import 'source_controller.dart';
import 'typing_formatter.dart';

/// A native source editor that lays out visible lines instead of one paragraph
/// containing the entire document. Source offsets and history stay shared.
class MarkdownSourceEditor extends StatefulWidget {
  const MarkdownSourceEditor({
    super.key,
    required this.controller,
    this.lineNumbers = true,
    this.fontSize = 14,
    this.typewriter = false,
    this.editingPreferences,
    this.onContextMenu,
  });
  final MarkdownEditorController controller;
  final bool lineNumbers;
  final double fontSize;
  final bool typewriter;
  final MarkdownEditingPreferences? editingPreferences;
  final ValueChanged<MarkdownContextRequest>? onContextMenu;
  @override
  State<MarkdownSourceEditor> createState() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
      ? _MarkdownSourceEditorState()
      : _MobileSourceEditorState();
}

class _MarkdownSourceEditorState extends State<MarkdownSourceEditor> {
  late MarkdownSourceEditingController _code;
  final _editorRegion = GlobalKey();
  CodeIndicatorValueNotifier? _indicator;
  late _SourceViewport _viewport;
  bool _restoringScroll = false;
  double _viewportHeight = 0;
  late final _vertical = ScrollController(
    initialScrollOffset: _viewport.vertical,
    keepScrollOffset: false,
  )..addListener(_rememberScroll);
  late final _horizontal = ScrollController(
    initialScrollOffset: _viewport.horizontal,
    keepScrollOffset: false,
  )..addListener(_rememberScroll);
  late final _scroll = CodeScrollController(
    verticalScroller: _vertical,
    horizontalScroller: _horizontal,
  );
  late final _toolbar = MobileSelectionToolbarController(
    builder:
        ({
          required context,
          required anchors,
          required controller,
          required onDismiss,
          required onRefresh,
        }) => AdaptiveTextSelectionToolbar.buttonItems(
          anchors: anchors,
          buttonItems: [
            ContextMenuButtonItem(
              type: ContextMenuButtonType.cut,
              onPressed: () {
                controller.cut();
                onDismiss();
              },
            ),
            ContextMenuButtonItem(
              type: ContextMenuButtonType.copy,
              onPressed: () {
                controller.copy();
                onDismiss();
              },
            ),
            ContextMenuButtonItem(
              type: ContextMenuButtonType.paste,
              onPressed: () {
                controller.paste();
                onDismiss();
              },
            ),
            ContextMenuButtonItem(
              type: ContextMenuButtonType.selectAll,
              onPressed: () {
                controller.selectAll();
                onRefresh();
              },
            ),
          ],
        ),
  );
  void _showContext(Offset position, {bool keyboard = false}) {
    final selection = widget.controller.selection;
    widget.onContextMenu?.call(
      MarkdownContextRequest(
        offset: selection.isValid ? selection.start : 0,
        selection: selection,
        position: position,
        keyboard: keyboard,
      ),
    );
  }

  late final _contextToolbar = _SourceContextToolbar(_showContext);

  @override
  void initState() {
    super.initState();
    _viewport = _sourceViewports[widget.controller] ??= _SourceViewport();
    _code = MarkdownSourceEditingController(
      widget.controller,
      indent: widget.editingPreferences?.indent ?? 2,
    );
    widget.controller.source.addListener(_revealSelection);
    widget.controller.sourceFocus.addListener(_revealSelection);
  }

  @override
  void didUpdateWidget(covariant MarkdownSourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.editingPreferences?.indent !=
            widget.editingPreferences?.indent) {
      oldWidget.controller.source.removeListener(_revealSelection);
      oldWidget.controller.sourceFocus.removeListener(_revealSelection);
      _code.dispose();
      _viewport = _sourceViewports[widget.controller] ??= _SourceViewport();
      final vertical = _viewport.vertical, horizontal = _viewport.horizontal;
      _restoringScroll = true;
      _code = MarkdownSourceEditingController(
        widget.controller,
        indent: widget.editingPreferences?.indent ?? 2,
      );
      widget.controller.source.addListener(_revealSelection);
      widget.controller.sourceFocus.addListener(_revealSelection);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_vertical.hasClients) _vertical.jumpTo(vertical);
        if (_horizontal.hasClients) _horizontal.jumpTo(horizontal);
        _restoringScroll = false;
      });
    }
    if (oldWidget.typewriter != widget.typewriter) _revealSelection();
  }

  void _rememberScroll() {
    if (_restoringScroll) return;
    if (_vertical.hasClients) {
      final position = _vertical.position, offset = _vertical.offset;
      if (position.hasViewportDimension &&
          _viewport.vertical - offset > position.viewportDimension) {
        // Re-Editor walks and lays out every intervening line on an upward
        // jump. With wrapping disabled, rebuilding its visible paragraph cache
        // lets it locate the target directly using the fixed line height.
        _code.forceRepaint();
      }
      _viewport.vertical = offset;
    }
    if (_horizontal.hasClients) _viewport.horizontal = _horizontal.offset;
  }

  void _revealSelection() {
    if (!widget.controller.sourceFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.sourceFocus.hasFocus) {
        _code.makeCursorVisible();
        if (widget.typewriter && _vertical.hasClients) {
          final height =
              MediaQuery.textScalerOf(context).scale(widget.fontSize) * 1.9;
          final position = _vertical.position;
          final target = (_code.selection.extentIndex * height).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
          _vertical.jumpTo(target);
        }
      }
    });
  }

  bool _showKeyboardContext() {
    final selection = widget.controller.selection;
    if (widget.onContextMenu == null ||
        !selection.isValid ||
        !_code.composing.isCollapsed) {
      return false;
    }
    final source = widget.controller.text;
    _code.makeCursorVisible();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.controller.text != source ||
          widget.controller.selection != selection) {
        return;
      }
      final box =
          _editorRegion.currentContext?.findRenderObject() as RenderBox?;
      final caret = _code.selection.extent;
      final paragraph = _indicator?.value?.paragraphs
          .where((line) => line.index == caret.index)
          .firstOrNull;
      final offset = paragraph?.getOffset(caret);
      if (box == null || paragraph == null || offset == null) return;
      // Use Re-Editor's laid-out paragraph, including tabs and font fallback.
      final local =
          offset +
          paragraph.offset +
          Offset(
            (widget.lineNumbers ? 48 : 0) - _horizontal.offset,
            paragraph.preferredLineHeight - _vertical.offset,
          );
      _showContext(
        box.localToGlobal(
          Offset(
            local.dx.clamp(0, box.size.width),
            local.dy.clamp(0, box.size.height),
          ),
        ),
        keyboard: true,
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
    return true;
  }

  @override
  void dispose() {
    widget.controller.source.removeListener(_revealSelection);
    widget.controller.sourceFocus.removeListener(_revealSelection);
    _code.dispose();
    _scroll.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final font = MarkdownCodeBlock.textStyle(context, widget.fontSize);
    return LayoutBuilder(
      key: _editorRegion,
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        final inset = widget.typewriter
            ? (_viewportHeight -
                      MediaQuery.textScalerOf(context).scale(widget.fontSize) *
                          1.9) /
                  2
            : null;
        return MarkdownContextShortcuts(
          onShow: widget.onContextMenu == null ? null : _showKeyboardContext,
          child: CodeEditor(
            key: PageStorageKey(('source', widget.controller)),
            controller: _code,
            scrollController: _scroll,
            focusNode: widget.controller.sourceFocus,
            toolbarController: widget.onContextMenu == null
                ? _toolbar
                : _contextToolbar,
            autofocus: false,
            wordWrap: false,
            autocompleteSymbols: widget.editingPreferences?.autoPair ?? false,
            chunkAnalyzer: const NonCodeChunkAnalyzer(),
            shortcutsActivatorsBuilder: const _SourceShortcuts(),
            style: CodeEditorStyle(
              fontFamily: font.fontFamily,
              fontFamilyFallback: font.fontFamilyFallback,
              fontSize: MediaQuery.textScalerOf(context).scale(widget.fontSize),
              fontHeight: 1.9,
              textColor: color.onSurface,
              backgroundColor: Colors.transparent,
              cursorColor: color.primary,
              selectionColor: color.primary.withValues(alpha: .18),
            ),
            padding: EdgeInsets.fromLTRB(
              widget.lineNumbers ? 4 : 28,
              inset ?? 26,
              28,
              inset ?? 70,
            ),
            indicatorBuilder: (context, editing, chunks, notifier) {
              _indicator = notifier;
              return widget.lineNumbers
                  ? SizedBox(
                      width: 48,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: DefaultCodeLineNumber(
                            controller: editing,
                            notifier: notifier,
                            textStyle: font.copyWith(
                              fontSize: 10,
                              color: color.onSurfaceVariant,
                            ),
                            focusedTextStyle: font.copyWith(
                              fontSize: 10,
                              color: color.primary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}

final _sourceViewports = Expando<_SourceViewport>();

final class _SourceViewport {
  double vertical = 0, horizontal = 0;
}

/// These commands belong to the host workspace, including its find panel.
class _SourceShortcuts extends DefaultCodeShortcutsActivatorsBuilder {
  const _SourceShortcuts();
  @override
  List<ShortcutActivator>? build(CodeShortcutType type) => switch (type) {
    CodeShortcutType.find ||
    CodeShortcutType.replace ||
    CodeShortcutType.save => const [],
    _ => super.build(type),
  };
}

// Keep the platform TextField input path until native platform validation.
class _MobileSourceEditorState extends State<MarkdownSourceEditor> {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  bool _centerScheduled = false;

  bool _showKeyboardContext() {
    if (widget.onContextMenu == null ||
        !widget.controller.source.value.composing.isCollapsed) {
      return false;
    }
    final viewport = _viewport.currentContext;
    final position = viewport == null
        ? null
        : markdownCaretMenuPosition(viewport);
    if (position == null) return false;
    final selection = widget.controller.selection;
    widget.onContextMenu!(
      MarkdownContextRequest(
        offset: selection.isValid ? selection.start : 0,
        selection: selection,
        position: position,
        keyboard: true,
      ),
    );
    return true;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.source.addListener(_center);
    widget.controller.sourceFocus.addListener(_center);
  }

  @override
  void didUpdateWidget(covariant MarkdownSourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.source.removeListener(_center);
      oldWidget.controller.sourceFocus.removeListener(_center);
      widget.controller.source.addListener(_center);
      widget.controller.sourceFocus.addListener(_center);
    }
    if (oldWidget.typewriter != widget.typewriter) _center();
  }

  void _center() {
    if (!widget.typewriter ||
        _centerScheduled ||
        !widget.controller.sourceFocus.hasFocus) {
      return;
    }
    _centerScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerScheduled = false;
      if (!mounted ||
          !widget.typewriter ||
          !widget.controller.sourceFocus.hasFocus ||
          !_scroll.hasClients) {
        return;
      }
      final viewport =
          _viewport.currentContext?.findRenderObject() as RenderBox?;
      if (viewport == null) return;
      RenderEditable? editable;
      void visit(RenderObject object) {
        if (object is RenderEditable) {
          editable = object;
        } else {
          object.visitChildren(visit);
        }
      }

      visit(viewport);
      final selection = widget.controller.source.selection;
      if (editable == null || !selection.isValid) return;
      final rect = editable!.getLocalRectForCaret(selection.extent);
      final center = viewport
          .globalToLocal(editable!.localToGlobal(rect.center))
          .dy;
      final position = _scroll.position;
      _scroll.jumpTo(
        (_scroll.offset + center - viewport.size.height / 2).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  void dispose() {
    widget.controller.source.removeListener(_center);
    widget.controller.sourceFocus.removeListener(_center);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final height =
            MediaQuery.textScalerOf(context).scale(widget.fontSize) * 1.9;
        return LayoutBuilder(
          key: PageStorageKey(('source', widget.controller)),
          builder: (context, constraints) {
            final top = widget.typewriter
                ? (constraints.maxHeight - height) / 2
                : 26.0;
            return Row(
              key: _viewport,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.lineNumbers)
                  SizedBox(
                    width: 48,
                    child: ClipRect(
                      child: CustomPaint(
                        painter: _SourceLineNumbers(
                          scroll: _scroll,
                          count:
                              widget.controller.document.lineStarts.length +
                              (widget.controller.source.text.endsWith('\n')
                                  ? 1
                                  : 0),
                          lineHeight: height,
                          top: top,
                          style: MarkdownCodeBlock.textStyle(context, 10)
                              .copyWith(
                                height: height / 10,
                                color: color.onSurfaceVariant,
                              ),
                          direction: Directionality.of(context),
                          scaler: MediaQuery.textScalerOf(context),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: MarkdownContextShortcuts(
                    onShow: widget.onContextMenu == null
                        ? null
                        : _showKeyboardContext,
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.tab): () =>
                            indentMarkdownSelection(
                              widget.controller.source,
                              widget.editingPreferences?.indent ?? 2,
                            ),
                        const SingleActivator(
                          LogicalKeyboardKey.tab,
                          shift: true,
                        ): () => indentMarkdownSelection(
                          widget.controller.source,
                          widget.editingPreferences?.indent ?? 2,
                          reverse: true,
                        ),
                      },
                      child: TextField(
                        controller: widget.controller.source,
                        contextMenuBuilder: widget.onContextMenu == null
                            ? null
                            : (context, editable) {
                                final position =
                                    editable.contextMenuAnchors.primaryAnchor;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  editable.hideToolbar();
                                  final selection = widget.controller.selection;
                                  widget.onContextMenu!(
                                    MarkdownContextRequest(
                                      offset: selection.isValid
                                          ? selection.start
                                          : 0,
                                      selection: selection,
                                      position: position,
                                    ),
                                  );
                                });
                                return const SizedBox.shrink();
                              },
                        focusNode: widget.controller.sourceFocus,
                        scrollController: _scroll,
                        keyboardType: TextInputType.multiline,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [
                          if (widget.editingPreferences?.autoPair == true)
                            const MarkdownPairFormatter(),
                          MarkdownTypingFormatter(),
                        ],
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        style:
                            MarkdownCodeBlock.textStyle(
                              context,
                              widget.fontSize,
                            ).copyWith(
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
                            top,
                            28,
                            widget.typewriter ? top : 70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SourceContextToolbar implements SelectionToolbarController {
  _SourceContextToolbar(this.onShow);
  final ValueChanged<Offset> onShow;
  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    visibility.value = false;
    onShow(anchors.primaryAnchor);
  }

  @override
  void hide(BuildContext context) {}
}

/// Paint only visible line labels. Scrolling never splits the entire source or
/// creates a widget for each line.
class _SourceLineNumbers extends CustomPainter {
  _SourceLineNumbers({
    required this.scroll,
    required this.count,
    required this.lineHeight,
    required this.style,
    required this.direction,
    required this.scaler,
    this.top = 26,
  }) : super(repaint: scroll);
  final ScrollController scroll;
  final int count;
  final double lineHeight;
  final double top;
  final TextStyle style;
  final TextDirection direction;
  final TextScaler scaler;
  @override
  void paint(Canvas canvas, Size size) {
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    final first = ((offset - top) / lineHeight).floor().clamp(0, count);
    final last = ((offset + size.height - top) / lineHeight).ceil().clamp(
      0,
      count,
    );
    final painter = TextPainter(textDirection: direction, textScaler: scaler);
    for (var i = first; i < last; i++) {
      painter.text = TextSpan(text: '${i + 1}', style: style);
      painter.layout();
      painter.paint(
        canvas,
        Offset(size.width - 12 - painter.width, top + i * lineHeight - offset),
      );
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_SourceLineNumbers oldDelegate) =>
      count != oldDelegate.count ||
      top != oldDelegate.top ||
      lineHeight != oldDelegate.lineHeight ||
      style != oldDelegate.style ||
      direction != oldDelegate.direction ||
      scaler != oldDelegate.scaler ||
      scroll != oldDelegate.scroll;
}
