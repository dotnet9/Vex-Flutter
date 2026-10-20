import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import 'code_block.dart';
import 'code_highlighting.dart';
import 'context_request.dart';
import 'context_shortcuts.dart';
import 'controller.dart';
import 'editing_preferences.dart';
import 'source_controller.dart';
import 'typing_formatter.dart';
import 'viewport_sync.dart';

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
  final _sourcePosition = MarkdownSourceViewport();
  final _editorRegion = GlobalKey();
  CodeIndicatorValueNotifier? _indicator;
  late _SourceViewport _viewport;
  bool _restoringScroll = false;
  double _viewportHeight = 0;
  double _gutterWidth = 0;
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
    widget.controller.navigation.addListener(_navigate);
    if (widget.controller.viewport.value == null &&
        widget.controller.navigation.value != null) {
      _navigate();
    }
  }

  @override
  void didUpdateWidget(covariant MarkdownSourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.editingPreferences?.indent !=
            widget.editingPreferences?.indent) {
      oldWidget.controller.source.removeListener(_revealSelection);
      oldWidget.controller.sourceFocus.removeListener(_revealSelection);
      oldWidget.controller.navigation.removeListener(_navigate);
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
      widget.controller.navigation.addListener(_navigate);
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

  void _navigate() => _revealSelection(force: true);

  void _revealSelection({bool force = false}) {
    if (!force && !widget.controller.sourceFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (force || widget.controller.sourceFocus.hasFocus)) {
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
            _gutterWidth - _horizontal.offset,
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
    widget.controller.navigation.removeListener(_navigate);
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
    final lineNumberStyle = font.copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(widget.fontSize),
      height: 1.9,
      color: color.onSurfaceVariant,
    );
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(widget.fontSize) * 1.9;
    double topPadding() =>
        widget.typewriter ? (_viewportHeight - lineHeight) / 2 : 26;
    return MarkdownViewportSync(
      controller: widget.controller,
      scroll: _vertical,
      readPosition: () {
        if (!_vertical.hasClients) return null;
        _sourcePosition.update(widget.controller.text);
        return _sourcePosition.offsetAtLine(
          (_vertical.offset - topPadding()) / lineHeight,
        );
      },
      writePosition: (offset) {
        _sourcePosition.update(widget.controller.text);
        final target =
            _sourcePosition.lineAtOffset(offset) * lineHeight + topPadding();
        _vertical.jumpTo(target.clamp(0.0, _vertical.position.maxScrollExtent));
      },
      child: LayoutBuilder(
        key: _editorRegion,
        builder: (context, constraints) {
          _viewportHeight = constraints.maxHeight;
          final inset = widget.typewriter
              ? (_viewportHeight -
                        MediaQuery.textScalerOf(context)
                                .scale(widget.fontSize) *
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
                fontSize: MediaQuery.textScalerOf(context)
                    .scale(widget.fontSize),
                fontHeight: 1.9,
                textColor: color.onSurface,
                backgroundColor: Colors.transparent,
                cursorColor: color.primary,
                selectionColor: color.primary.withValues(alpha: .18),
                codeTheme: CodeHighlightTheme(
                  languages: {
                    'markdown': CodeHighlightThemeMode(
                      mode: MarkdownCodeHighlighting.languages['markdown']!,
                      maxSize: 256 * 1024,
                      maxLineLength: 16 * 1024,
                    ),
                  },
                  theme: MarkdownCodeHighlighting.theme(color.brightness),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                widget.lineNumbers ? 4 : 28,
                inset ?? 26,
                28,
                inset ?? 70,
              ),
              indicatorBuilder: (context, editing, chunks, notifier) {
                _indicator = notifier;
                final painter = TextPainter(
                  text: TextSpan(
                    text:
                        '0' * editing.lineCount.toString().length.clamp(3, 12),
                    style: lineNumberStyle,
                  ),
                  textDirection: Directionality.of(context),
                )..layout();
                _gutterWidth = widget.lineNumbers
                    ? painter.width.ceil() + 16
                    : 0;
                painter.dispose();
                return widget.lineNumbers
                    ? SizedBox(
                        width: _gutterWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: DefaultCodeLineNumber(
                              controller: editing,
                              notifier: notifier,
                              textStyle: lineNumberStyle,
                              focusedTextStyle: lineNumberStyle.copyWith(
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
      ),
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
  late _SourceViewport _savedViewport;
  bool _restoringScroll = false;
  late final _scroll = ScrollController(
    initialScrollOffset: _savedViewport.vertical,
    keepScrollOffset: false,
  )..addListener(_rememberScroll);
  final _viewport = GlobalKey();
  final _field = GlobalKey(), _gutter = GlobalKey();
  String? _lineSource;
  List<int> _lineStarts = const [0];
  bool _centerScheduled = false;
  bool _forceReveal = false;

  void _rememberScroll() {
    if (!_restoringScroll && _scroll.hasClients) {
      _savedViewport.vertical = _scroll.offset;
    }
  }

  RenderEditable? _editable() {
    RenderEditable? result;
    void visit(RenderObject object) {
      if (object is RenderEditable) {
        result = object;
      } else {
        object.visitChildren(visit);
      }
    }

    final object = _field.currentContext?.findRenderObject();
    if (object != null) visit(object);
    return result;
  }

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
    _savedViewport = _sourceViewports[widget.controller] ??= _SourceViewport();
    widget.controller.source.addListener(_center);
    widget.controller.sourceFocus.addListener(_center);
    widget.controller.navigation.addListener(_navigate);
    if (widget.controller.viewport.value == null &&
        widget.controller.navigation.value != null) {
      _navigate();
    }
  }

  @override
  void didUpdateWidget(covariant MarkdownSourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.source.removeListener(_center);
      oldWidget.controller.sourceFocus.removeListener(_center);
      oldWidget.controller.navigation.removeListener(_navigate);
      widget.controller.source.addListener(_center);
      widget.controller.sourceFocus.addListener(_center);
      widget.controller.navigation.addListener(_navigate);
      _savedViewport = _sourceViewports[widget.controller] ??=
          _SourceViewport();
      final offset = _savedViewport.vertical;
      _restoringScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
        }
        _restoringScroll = false;
        if (widget.controller.viewport.value == null &&
            widget.controller.navigation.value != null) {
          _navigate();
        }
      });
    }
    if (oldWidget.typewriter != widget.typewriter) _center();
  }

  void _navigate() => _center(force: true);

  void _center({bool force = false}) {
    _forceReveal |= force;
    if (_centerScheduled ||
        (!force &&
            (!widget.typewriter || !widget.controller.sourceFocus.hasFocus))) {
      return;
    }
    _centerScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerScheduled = false;
      final forced = _forceReveal;
      _forceReveal = false;
      if (!mounted ||
          (!forced &&
              (!widget.typewriter ||
                  !widget.controller.sourceFocus.hasFocus)) ||
          !_scroll.hasClients) {
        return;
      }
      final viewport =
          _viewport.currentContext?.findRenderObject() as RenderBox?;
      if (viewport == null) return;
      final editable = _editable();
      final selection = widget.controller.source.selection;
      if (editable == null || !selection.isValid) return;
      final rect = editable.getLocalRectForCaret(selection.extent);
      final center = viewport
          .globalToLocal(editable.localToGlobal(rect.center))
          .dy;
      final position = _scroll.position;
      final delta = widget.typewriter
          ? center - viewport.size.height / 2
          : center < 26
          ? center - 26
          : center > viewport.size.height - 26
          ? center - viewport.size.height + 26
          : 0;
      _scroll.jumpTo(
        (_scroll.offset + delta).clamp(
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
    widget.controller.navigation.removeListener(_navigate);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return MarkdownViewportSync(
      controller: widget.controller,
      scroll: _scroll,
      readPosition: () {
        final editable = _editable();
        if (editable == null) return null;
        final point = editable.localToGlobal(Offset.zero);
        final start = editable.getPositionForPoint(point);
        final end = editable.getPositionForPoint(
          point + Offset(0, editable.preferredLineHeight),
        );
        final rect = editable.getLocalRectForCaret(start);
        final fraction = (-rect.top / editable.preferredLineHeight).clamp(
          0.0,
          1.0,
        );
        return start.offset + (end.offset - start.offset) * fraction;
      },
      writePosition: (offset) {
        final editable = _editable();
        if (editable == null) return;
        final position = TextPosition(
          offset: offset.floor().clamp(0, widget.controller.text.length),
        );
        final rect = editable.getLocalRectForCaret(position);
        _scroll.jumpTo(
          (_scroll.offset + rect.top).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          ),
        );
      },
      child: ListenableBuilder(
        listenable: widget.controller.source,
        builder: (context, _) {
          final source = widget.controller.source.text;
          if (_lineSource != source) {
            _lineSource = source;
            _lineStarts = [
              0,
              for (final match in RegExp(r'\r\n|\r|\n').allMatches(source))
                match.end,
            ];
          }
          final font = MarkdownCodeBlock.textStyle(
            context,
            widget.fontSize,
          ).copyWith(height: 1.9, color: color.onSurface);
          final scaler = MediaQuery.textScalerOf(context);
          final labels = TextPainter(
            text: TextSpan(
              text: '0' * _lineStarts.length.toString().length.clamp(3, 12),
              style: font,
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();
          final gutterWidth = labels.width.ceil() + 16.0;
          labels.dispose();
          final height = scaler.scale(widget.fontSize) * 1.9;
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
                      width: gutterWidth,
                      child: ClipRect(
                        child: CustomPaint(
                          key: _gutter,
                          painter: _SourceLineNumbers(
                            scroll: _scroll,
                            lineStarts: _lineStarts,
                            editable: _editable,
                            gutter: _gutter,
                            style: font.copyWith(color: color.onSurfaceVariant),
                            direction: Directionality.of(context),
                            scaler: scaler,
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
                          key: _field,
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
                                    final selection =
                                        widget.controller.selection;
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
                          style: font,
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
      ),
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
    required this.lineStarts,
    required this.editable,
    required this.gutter,
    required this.style,
    required this.direction,
    required this.scaler,
  }) : super(repaint: scroll);
  final ScrollController scroll;
  final List<int> lineStarts;
  final RenderEditable? Function() editable;
  final GlobalKey gutter;
  final TextStyle style;
  final TextDirection direction;
  final TextScaler scaler;

  int _lineAt(int offset) {
    var low = 0, high = lineStarts.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (lineStarts[middle] <= offset) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final text = editable();
    final box = gutter.currentContext?.findRenderObject() as RenderBox?;
    if (text == null || box == null) return;
    final first = _lineAt(
      text.getPositionForPoint(box.localToGlobal(Offset.zero)).offset,
    );
    final last = _lineAt(
      text
          .getPositionForPoint(box.localToGlobal(Offset(0, size.height)))
          .offset,
    );
    final painter = TextPainter(textDirection: direction, textScaler: scaler);
    for (var i = first; i <= last; i++) {
      final caret = text.getLocalRectForCaret(
        TextPosition(offset: lineStarts[i]),
      );
      final y = box.globalToLocal(text.localToGlobal(caret.center)).dy;
      painter.text = TextSpan(text: '${i + 1}', style: style);
      painter.layout();
      if (y + painter.height / 2 < 0 || y - painter.height / 2 > size.height) {
        continue;
      }
      painter.paint(
        canvas,
        Offset(size.width - 12 - painter.width, y - painter.height / 2),
      );
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_SourceLineNumbers oldDelegate) =>
      lineStarts != oldDelegate.lineStarts ||
      editable != oldDelegate.editable ||
      gutter != oldDelegate.gutter ||
      style != oldDelegate.style ||
      direction != oldDelegate.direction ||
      scaler != oldDelegate.scaler ||
      scroll != oldDelegate.scroll;
}
