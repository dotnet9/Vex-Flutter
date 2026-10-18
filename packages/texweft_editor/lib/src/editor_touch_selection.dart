part of 'editor.dart';

extension _InstantTouchSelection on _MarkdownInstantEditorState {
  bool get _isTouchPointer =>
      _lastPointerKind == PointerDeviceKind.touch ||
      _lastPointerKind == PointerDeviceKind.stylus;

  void _touchContextRequest(MarkdownContextRequest request) {
    final selection = request.selection;
    if (_isTouchPointer &&
        !request.keyboard &&
        selection != null &&
        !selection.isCollapsed) {
      _setDocumentSelection(
        selection.baseOffset,
        selection.extentOffset,
        request.position,
        touch: true,
      );
    } else {
      widget.onContextMenu?.call(request);
    }
  }

  void _startTouchSelection(Offset position) {
    if (!_input.value.composing.isCollapsed) return;
    final selection = _geometryAt(position)?.wordAt(position);
    if (selection == null || selection.isCollapsed) return;
    _setDocumentSelection(
      selection.baseOffset,
      selection.extentOffset,
      position,
      touch: true,
    );
    _dragSourceBase = selection.baseOffset;
  }

  void _moveTouchSelection(Offset position) {
    if (!_touchSelection || _dragSourceBase == null) return;
    _touchToolbar = false;
    _dragPosition = position;
    _updateDocumentDrag(position);
    _startDocumentDragScroll();
  }

  void _startTouchHandle(
    bool start,
    Offset position,
    MarkdownSelectionEndpoint endpoint,
  ) {
    _navigation.cancel();
    final selection = widget.controller.selection;
    _touchHandleStart = start;
    _dragSourceBase = start ? selection.end : selection.start;
    // Keep the finger's initial distance from the text instead of jumping the
    // endpoint to the center of the handle's larger hit target.
    _touchHandleDelta =
        endpoint.point - Offset(0, endpoint.height / 2) - position;
    _rebuildSelection(() => _touchToolbar = false);
  }

  void _moveTouchHandle(Offset position) {
    _moveTouchSelection(position + _touchHandleDelta);
  }

  void _endTouchSelectionDrag() {
    _touchHandleStart = null;
    _endDocumentDrag();
    if (mounted && _touchSelection) {
      _rebuildSelection(() => _touchToolbar = true);
    }
  }

  void _showTouchSelectionContext() {
    _rebuildSelection(() => _touchToolbar = false);
    widget.onContextMenu?.call(
      MarkdownContextRequest(
        offset: widget.controller.selection.start,
        selection: widget.controller.selection,
        position: _selectionAnchor,
        onEdit: _selectionFocus.requestFocus,
        onEditAt: _editAt,
      ),
    );
  }
}

class _MarkdownTouchSelectionOverlay extends StatefulWidget {
  const _MarkdownTouchSelectionOverlay({
    required this.selection,
    required this.sourceLength,
    required this.geometries,
    required this.scroll,
    required this.toolbar,
    required this.onHandleStart,
    required this.onHandleUpdate,
    required this.onHandleEnd,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onSelectAll,
    this.onMore,
  });
  final TextSelection selection;
  final int sourceLength;
  final Map<int, MarkdownSelectionGeometry> geometries;
  final ScrollController scroll;
  final bool toolbar;
  final void Function(bool, Offset, MarkdownSelectionEndpoint) onHandleStart;
  final ValueChanged<Offset> onHandleUpdate;
  final VoidCallback onHandleEnd, onCopy, onCut, onPaste, onSelectAll;
  final VoidCallback? onMore;

  @override
  State<_MarkdownTouchSelectionOverlay> createState() =>
      _MarkdownTouchSelectionOverlayState();
}

class _MarkdownTouchSelectionOverlayState
    extends State<_MarkdownTouchSelectionOverlay> {
  MarkdownSelectionEndpoint? _start, _end;
  final _toolbarPortal = OverlayPortalController();
  bool _scheduled = false;
  bool? _dragging;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _MarkdownTouchSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scroll != widget.scroll) {
      oldWidget.scroll.removeListener(_schedule);
      widget.scroll.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      MarkdownSelectionEndpoint? at(int offset, bool end) {
        final candidates = widget.geometries.values.where(
          (g) =>
              g.start <= offset &&
              g.start + g.raw.length >= offset &&
              g.box != null,
        );
        if (candidates.isEmpty) return null;
        return (end ? candidates.first : candidates.last).endpoint(
          offset,
          end: end,
        );
      }

      setState(() {
        _start =
            at(widget.selection.start, false) ??
            (_dragging == true ? _start : null);
        _end =
            at(widget.selection.end, true) ??
            (_dragging == false ? _end : null);
      });
      if (widget.toolbar) {
        _toolbarPortal.show();
      } else {
        _toolbarPortal.hide();
      }
    });
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_schedule);
    super.dispose();
  }

  Widget _handle(
    bool start,
    MarkdownSelectionEndpoint endpoint,
    RenderBox root,
  ) {
    final apple =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;
    final controls = apple
        ? cupertinoTextSelectionControls
        : materialTextSelectionControls;
    final left = start == (endpoint.direction == TextDirection.ltr);
    final type = left
        ? TextSelectionHandleType.left
        : TextSelectionHandleType.right;
    final size = controls.getHandleSize(endpoint.height);
    final anchor = controls.getHandleAnchor(type, endpoint.height);
    final point = root.globalToLocal(endpoint.point);
    final visible =
        point.dy >= 0 &&
        point.dy <= root.size.height &&
        point.dx >= 0 &&
        point.dx <= root.size.width;
    final target = Size(
      size.width < 48 ? 48 : size.width,
      size.height < 48 ? 48 : size.height,
    );
    final inset = Offset(
      (target.width - size.width) / 2,
      (target.height - size.height) / 2,
    );
    return Positioned(
      left: point.dx - anchor.dx - inset.dx,
      top: point.dy - anchor.dy - inset.dy,
      width: target.width,
      height: target.height,
      child: IgnorePointer(
        ignoring: !visible && _dragging != start,
        child: Opacity(
          opacity: visible ? 1 : 0,
          child: GestureDetector(
            key: ValueKey(
              'instant-selection-${start ? 'start' : 'end'}-handle',
            ),
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTap: widget.onHandleEnd,
            onPanStart: (details) {
              _dragging = start;
              widget.onHandleStart(start, details.globalPosition, endpoint);
            },
            onPanUpdate: (details) =>
                widget.onHandleUpdate(details.globalPosition),
            onPanEnd: (_) {
              _dragging = null;
              widget.onHandleEnd();
            },
            onPanCancel: () {
              _dragging = null;
              widget.onHandleEnd();
            },
            child: Center(
              child: controls.buildHandle(context, type, endpoint.height),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final root = context.findRenderObject() as RenderBox?;
    return OverlayPortal(
      controller: _toolbarPortal,
      overlayChildBuilder: _toolbar,
      child: root == null || !root.hasSize
          ? const SizedBox.expand()
          : Stack(
              clipBehavior: Clip.none,
              children: [
                if (_start case final start?) _handle(true, start, root),
                if (_end case final end?) _handle(false, end, root),
              ],
            ),
    );
  }

  Widget _toolbar(BuildContext overlayContext) {
    final root = context.findRenderObject() as RenderBox?;
    if (root == null || !root.hasSize) return const SizedBox.shrink();
    Offset? visible(MarkdownSelectionEndpoint? endpoint) {
      if (endpoint == null) return null;
      final point = root.globalToLocal(endpoint.point);
      return (Offset.zero & root.size).contains(point) ? point : null;
    }

    final visibleStart = visible(_start), visibleEnd = visible(_end);
    final anchor = visibleStart ?? visibleEnd;
    if (!widget.toolbar || anchor == null) {
      return const SizedBox.shrink();
    }
    final overlay =
        Overlay.of(overlayContext).context.findRenderObject()! as RenderBox;
    final above =
        overlay.globalToLocal(root.localToGlobal(anchor)) -
        Offset(0, (visibleStart != null ? _start : _end)!.height);
    final below =
        overlay.globalToLocal(root.localToGlobal(visibleEnd ?? anchor)) +
        const Offset(0, 32);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: TextSelectionToolbarAnchors(
        primaryAnchor: above,
        secondaryAnchor: below,
      ),
      buttonItems: [
        ContextMenuButtonItem(
          type: ContextMenuButtonType.cut,
          onPressed: widget.onCut,
        ),
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: widget.onCopy,
        ),
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: widget.onPaste,
        ),
        if (widget.selection.start != 0 ||
            widget.selection.end != widget.sourceLength)
          ContextMenuButtonItem(
            type: ContextMenuButtonType.selectAll,
            onPressed: widget.onSelectAll,
          ),
        if (widget.onMore != null)
          ContextMenuButtonItem(
            label: MaterialLocalizations.of(context).moreButtonTooltip,
            onPressed: widget.onMore,
          ),
      ],
    );
  }
}
