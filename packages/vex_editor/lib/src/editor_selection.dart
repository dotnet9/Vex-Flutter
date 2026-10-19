part of 'editor.dart';

extension _InstantDocumentSelection on _MarkdownInstantEditorState {
  Widget _selectionBlock(
    MarkdownBlock block,
    String source,
    Widget child, {
    bool active = false,
  }) {
    final raw = block.range.slice(source);
    final bodyStart = active
        ? _codeFence?.bodyOffset(code: _input.text, language: _language.text) ??
              _prefix.length
        : null;
    var geometry = _selectionGeometries[block.range.start];
    if (geometry == null ||
        geometry.raw != raw ||
        geometry.kind != block.kind ||
        geometry.preferences != widget.preferences ||
        geometry.literalStart != bodyStart ||
        geometry.literalText != (active ? _input.text : null)) {
      geometry = MarkdownSelectionGeometry(
        key: geometry?.key ?? GlobalKey(),
        start: block.range.start,
        raw: raw,
        kind: block.kind,
        preferences: widget.preferences,
        literalStart: bodyStart,
        literalText: active ? _input.text : null,
        atomic:
            block.kind == MarkdownBlockKind.math ||
            (block.kind == MarkdownBlockKind.code &&
                MarkdownCodeFence.parse(raw)?.language.toLowerCase() ==
                    'mermaid'),
      );
      _selectionGeometries[block.range.start] = geometry;
    }
    return CustomPaint(
      key: geometry.key,
      foregroundPainter: _documentSelection
          ? MarkdownSelectionPainter(
              geometry,
              widget.controller.selection,
              Theme.of(context).colorScheme.primary.withValues(alpha: .22),
            )
          : null,
      child: child,
    );
  }

  MarkdownSelectionGeometry? _geometryAt(Offset global) {
    final visible = _selectionGeometries.values
        .where((g) => g.box != null)
        .toList();
    if (visible.isEmpty) return null;
    double distance(MarkdownSelectionGeometry geometry) {
      final box = geometry.box!, local = box.globalToLocal(global);
      if (local.dy < 0) return -local.dy;
      return (local.dy - box.size.height).clamp(0, double.infinity).toDouble();
    }

    visible.sort((a, b) => distance(a).compareTo(distance(b)));
    return visible.first;
  }

  void _documentPointerDown(PointerDownEvent event) {
    _navigation.cancel();
    _lastPointerKind = event.kind;
    if (event.kind != PointerDeviceKind.mouse &&
        _documentSelection &&
        _selectionInput.value.composing.isCollapsed) {
      _rebuildSelection(_clearDocumentSelection);
    }
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton ||
        !_input.value.composing.isCollapsed) {
      return;
    }
    final geometry = _geometryAt(event.position);
    if (geometry == null) return;
    if (_documentSelection && !HardwareKeyboard.instance.isShiftPressed) {
      _rebuildSelection(_clearDocumentSelection);
    }
    _dragOrigin = event.position;
    _dragPosition = event.position;
    _dragPointer = event.pointer;
    _dragBase = null;
    _dragBlockStart = geometry.start;
    final selection = widget.controller.selection;
    _dragSourceBase =
        HardwareKeyboard.instance.isShiftPressed && selection.isValid
        ? selection.baseOffset
        : geometry.hit(event.position);
    if (HardwareKeyboard.instance.isShiftPressed) {
      _setDocumentSelection(
        _dragSourceBase!,
        geometry.hit(event.position),
        event.position,
      );
    }
  }

  void _moveDocumentDrag(PointerMoveEvent event) {
    if (_dragOrigin == null ||
        _dragPointer != event.pointer ||
        event.kind != PointerDeviceKind.mouse ||
        (event.position - _dragOrigin!).distance < kPrecisePointerPanSlop) {
      return;
    }
    _dragPosition = event.position;
    _updateDocumentDrag(event.position);
    _startDocumentDragScroll();
  }

  void _startDocumentDragScroll() {
    _dragScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final position = _dragPosition;
      final viewport =
          _viewportRegion.currentContext?.findRenderObject() as RenderBox?;
      if (!mounted ||
          position == null ||
          viewport == null ||
          !_scroll.hasClients) {
        return;
      }
      final y = viewport.globalToLocal(position).dy;
      const edge = 36.0;
      final delta = y < edge
          ? (y - edge) / 5
          : y > viewport.size.height - edge
          ? (y - viewport.size.height + edge) / 5
          : 0.0;
      if (delta == 0) return;
      final scroll = _scroll.position;
      final target = (_scroll.offset + delta.clamp(-28, 28)).clamp(
        scroll.minScrollExtent,
        scroll.maxScrollExtent,
      );
      if (target == _scroll.offset) return;
      _scroll.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dragPosition == position) _updateDocumentDrag(position);
      });
    });
  }

  void _updateDocumentDrag(Offset position) {
    final geometry = _geometryAt(position), base = _dragSourceBase;
    if (geometry == null || base == null) return;
    if (_documentSelection || geometry.start != _dragBlockStart) {
      var extent = geometry.hit(position);
      if (_touchHandleStart != null) {
        final source = widget.controller.text;
        final boundary = CharacterBoundary(source);
        extent = _touchHandleStart!
            ? extent.clamp(0, boundary.getLeadingTextBoundaryAt(base - 1) ?? 0)
            : extent.clamp(
                boundary.getTrailingTextBoundaryAt(base) ?? source.length,
                source.length,
              );
      }
      _setDocumentSelection(base, extent, position);
      return;
    }
    if (_checkpoint == null || geometry.start != _start) return;
    final editable = _editable();
    if (editable == null) return;
    _dragBase ??= editable
        .getPositionForPoint(editable.globalToLocal(_dragOrigin!))
        .offset;
    _input.selection = TextSelection(
      baseOffset: _dragBase!,
      extentOffset: editable
          .getPositionForPoint(editable.globalToLocal(position))
          .offset,
    );
  }

  void _endDocumentDrag() {
    _dragOrigin = _dragPosition = null;
    _dragBase = _dragSourceBase = _dragBlockStart = _dragPointer = null;
    _dragScrollTimer?.cancel();
    _dragScrollTimer = null;
  }

  void _clearDocumentSelection() {
    if (!_documentSelection) return;
    _documentSelection = false;
    _touchSelection = _touchToolbar = _touchKeyboard = false;
    _touchHandleStart = null;
    _endDocumentDrag();
    _selectionFocus.unfocus();
    _selectionSync = true;
    _selectionInput.clear();
    _selectionSync = false;
  }

  void _setDocumentSelection(
    int base,
    int extent,
    Offset anchor, {
    bool touch = false,
  }) {
    final source = widget.controller.session.text;
    final selection = TextSelection(
      baseOffset: base.clamp(0, source.length),
      extentOffset: extent.clamp(0, source.length),
    );
    if (selection.isCollapsed && !_documentSelection) return;
    if (touch && !_touchSelection) {
      _touchKeyboard =
          _focus.hasFocus || MediaQuery.viewInsetsOf(context).bottom > 0;
    }
    if (!_documentSelection) _finish();
    _writing = true;
    try {
      widget.controller.select(selection.baseOffset, selection.extentOffset);
    } finally {
      _writing = false;
    }
    _selectedOriginal = selection.textInside(source);
    _selectionRevision = widget.controller.session.revision;
    _selectionSync = true;
    _selectionInput.value = TextEditingValue(
      text: _selectedOriginal,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: _selectedOriginal.length,
      ),
    );
    _selectionSync = false;
    _rebuildSelection(() {
      _documentSelection = true;
      _selectionAnchor = anchor;
      if (touch) _touchSelection = _touchToolbar = true;
    });
    _selectionFocus.requestFocus();
  }

  void _observeDocumentSelection() {
    if (_writing || !mounted) return;
    final controller = widget.controller, selection = controller.selection;
    if (controller.source.text != controller.session.text ||
        !controller.source.value.composing.isCollapsed) {
      return;
    }
    if (!selection.isValid || selection.isCollapsed) {
      if (_documentSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              widget.controller == controller &&
              controller.selection == selection) {
            _rebuildSelection(_clearDocumentSelection);
          }
        });
      }
      return;
    }
    if (_checkpoint != null &&
        selection.start >= _start &&
        selection.end <= _end) {
      return;
    }
    if (controller.document.blocks.any(
          (block) =>
              selection.start >= block.range.start &&
              selection.end <= block.range.end,
        ) &&
        !(selection.start == 0 &&
            selection.end == controller.session.text.length)) {
      return;
    }
    if (_documentSelection &&
        selection.textInside(controller.session.text) == _selectedOriginal) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.controller != controller ||
          controller.selection != selection ||
          _writing ||
          controller.source.text != controller.session.text) {
        return;
      }
      final viewport =
          _viewportRegion.currentContext?.findRenderObject() as RenderBox?;
      _setDocumentSelection(
        selection.baseOffset,
        selection.extentOffset,
        viewport?.localToGlobal(const Offset(24, 24)) ?? Offset.zero,
      );
    });
  }

  void _selectionBufferChanged() {
    if (_selectionSync ||
        !_documentSelection ||
        _selectionInput.text == _selectedOriginal) {
      return;
    }
    if (!_selectionInput.value.composing.isCollapsed) {
      _rebuildSelection(() {});
      return;
    }
    final replacement = _selectionInput.text;
    final start = widget.controller.selection.start;
    _clearDocumentSelection();
    widget.controller.replaceSelection(replacement, label: '替换文档选区');
    _editAt(start + replacement.length);
  }

  void _selectionCollapse(bool end) {
    if (!_selectionInput.value.composing.isCollapsed) return;
    final selected = widget.controller.selection;
    _clearDocumentSelection();
    _editAt(end ? selected.end : selected.start);
  }

  void _selectionExtend(bool forward) {
    if (!_selectionInput.value.composing.isCollapsed) return;
    final source = widget.controller.session.text;
    final selection = widget.controller.selection;
    final boundary = CharacterBoundary(source);
    final offset = forward
        ? boundary.getTrailingTextBoundaryAt(selection.extentOffset) ??
              source.length
        : boundary.getLeadingTextBoundaryAt(selection.extentOffset - 1) ?? 0;
    _setDocumentSelection(selection.baseOffset, offset, _selectionAnchor);
  }

  void _selectWholeDocument() {
    final viewport =
        _viewportRegion.currentContext?.findRenderObject() as RenderBox?;
    _setDocumentSelection(
      0,
      widget.controller.session.text.length,
      viewport?.localToGlobal(const Offset(24, 24)) ?? Offset.zero,
    );
  }

  bool _selectionKeyboardContext() {
    if (widget.onContextMenu == null ||
        !_selectionInput.value.composing.isCollapsed) {
      return false;
    }
    widget.onContextMenu!(
      MarkdownContextRequest(
        offset: widget.controller.selection.start,
        selection: widget.controller.selection,
        position: _selectionAnchor,
        keyboard: true,
        onEdit: _selectionFocus.requestFocus,
        onEditAt: _editAt,
      ),
    );
    return true;
  }

  Future<void> _selectionCopy({bool cut = false}) async {
    final controller = widget.controller, source = controller.text;
    final revision = controller.session.revision;
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    await Clipboard.setData(ClipboardData(text: selection.textInside(source)));
    if (!cut ||
        !mounted ||
        widget.controller != controller ||
        controller.text != source ||
        controller.session.revision != revision ||
        controller.selection != selection ||
        !_documentSelection) {
      return;
    }
    _clearDocumentSelection();
    controller.replaceSelection('', label: '剪切文档选区');
    _editAt(selection.start);
  }

  Future<void> _selectionPaste() async {
    final controller = widget.controller, source = controller.text;
    final revision = controller.session.revision;
    final selection = controller.selection;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted ||
        data?.text == null ||
        widget.controller != controller ||
        controller.text != source ||
        controller.session.revision != revision ||
        controller.selection != selection ||
        !_documentSelection) {
      return;
    }
    _clearDocumentSelection();
    controller.replaceSelection(data!.text!, label: '粘贴文档选区');
    _editAt(selection.start + data.text!.length);
  }

  Widget _documentSelectionInput(ColorScheme colors) {
    final root = context.findRenderObject() as RenderBox?;
    final anchor = root?.globalToLocal(_selectionAnchor) ?? Offset.zero;
    final composing = !_selectionInput.value.composing.isCollapsed;
    return Positioned(
      left: anchor.dx
          .clamp(0, ((root?.size.width ?? 320) - 240).clamp(0, double.infinity))
          .toDouble(),
      top: anchor.dy
          .clamp(0, ((root?.size.height ?? 200) - 40).clamp(0, double.infinity))
          .toDouble(),
      width: 240,
      height: 40,
      child: IgnorePointer(
        child: Opacity(
          opacity: composing ? 1 : 0,
          child: MarkdownContextShortcuts(
            onShow: _selectionKeyboardContext,
            child: CallbackShortcuts(
              bindings: {
                for (final meta in [false, true]) ...{
                  SingleActivator(
                    LogicalKeyboardKey.keyA,
                    control: !meta,
                    meta: meta,
                  ): () => _setDocumentSelection(
                    0,
                    widget.controller.text.length,
                    _selectionAnchor,
                  ),
                  SingleActivator(
                    LogicalKeyboardKey.keyC,
                    control: !meta,
                    meta: meta,
                  ): () =>
                      unawaited(_selectionCopy()),
                  SingleActivator(
                    LogicalKeyboardKey.keyX,
                    control: !meta,
                    meta: meta,
                  ): () =>
                      unawaited(_selectionCopy(cut: true)),
                  SingleActivator(
                    LogicalKeyboardKey.keyV,
                    control: !meta,
                    meta: meta,
                  ): () =>
                      unawaited(_selectionPaste()),
                  SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    control: !meta,
                    meta: meta,
                  ): () =>
                      widget.controller.session.undo(),
                  SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    control: !meta,
                    meta: meta,
                    shift: true,
                  ): () =>
                      widget.controller.session.redo(),
                },
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _selectionCollapse(false),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _selectionCollapse(true),
                const SingleActivator(
                  LogicalKeyboardKey.arrowLeft,
                  shift: true,
                ): () =>
                    _selectionExtend(false),
                const SingleActivator(
                  LogicalKeyboardKey.arrowRight,
                  shift: true,
                ): () =>
                    _selectionExtend(true),
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    _selectionCollapse(false),
              },
              child: TextField(
                key: const ValueKey('instant-document-selection-input'),
                groupId: this,
                controller: _selectionInput,
                focusNode: _selectionFocus,
                keyboardType: _touchSelection && !_touchKeyboard
                    ? TextInputType.none
                    : TextInputType.multiline,
                maxLines: null,
                autocorrect: false,
                enableSuggestions: false,
                style: _reader.styleSheet(context).p,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  filled: composing,
                  fillColor: colors.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
