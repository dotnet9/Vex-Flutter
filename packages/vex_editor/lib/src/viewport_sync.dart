import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

import 'controller.dart';

/// Coalesces scroll updates without rebuilding the document or moving its caret.
/// Only the pane receiving user input publishes; layout corrections in followers
/// cannot take ownership and feed their estimated positions back to the leader.
class MarkdownViewportSync extends StatefulWidget {
  const MarkdownViewportSync({
    super.key,
    required this.controller,
    required this.scroll,
    required this.readPosition,
    required this.writePosition,
    required this.child,
  });
  final MarkdownEditorController controller;
  final ScrollController scroll;
  final double? Function() readPosition;
  final ValueChanged<double> writePosition;
  final Widget child;

  @override
  State<MarkdownViewportSync> createState() => _MarkdownViewportSyncState();
}

class _MarkdownViewportSyncState extends State<MarkdownViewportSync> {
  bool _scheduled = false;
  int _followRevision = 0;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_scrolled);
    widget.controller.viewport.addListener(_follow);
    _follow();
  }

  @override
  void didUpdateWidget(MarkdownViewportSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scroll != widget.scroll) {
      oldWidget.scroll.removeListener(_scrolled);
      widget.scroll.addListener(_scrolled);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.viewport.removeListener(_follow);
      widget.controller.viewport.addListener(_follow);
      _follow();
    }
  }

  void _claim() {
    widget.controller.viewportOwner = this;
    _followRevision++;
  }

  void _scrolled() {
    if (_scheduled || widget.controller.viewportOwner != this) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || widget.controller.viewportOwner != this) return;
      final offset = widget.readPosition();
      if (offset == null || !offset.isFinite) return;
      final previous = widget.controller.viewport.value;
      if (previous?.origin == this && (previous!.offset - offset).abs() < .01) {
        return;
      }
      widget.controller.viewport.value = MarkdownViewportPosition(offset, this);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _follow() {
    final position = widget.controller.viewport.value;
    final revision = ++_followRevision;
    if (position == null || position.origin == this) return;
    void apply(Duration _) {
      if (!mounted ||
          revision != _followRevision ||
          widget.controller.viewportOwner == this ||
          !widget.scroll.hasClients) {
        return;
      }
      widget.writePosition(position.offset);
    }

    WidgetsBinding.instance.addPostFrameCallback((time) {
      apply(time);
      // The first jump resolves an unbuilt virtual item's estimated height.
      // Apply its fraction again once its actual geometry is available.
      WidgetsBinding.instance.addPostFrameCallback(apply);
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_scrolled);
    widget.controller.viewport.removeListener(_follow);
    if (widget.controller.viewportOwner == this) {
      widget.controller.viewportOwner = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: (focused) {
      if (focused) _claim();
    },
    onKeyEvent: (_, _) {
      _claim();
      return KeyEventResult.ignored;
    },
    child: Listener(
      onPointerDown: (_) => _claim(),
      onPointerSignal: (_) => _claim(),
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical &&
              notification.direction != ScrollDirection.idle) {
            _claim();
          }
          return false;
        },
        child: widget.child,
      ),
    ),
  );
}

/// Maps the visible fraction of a rendered block to the same source interval
/// used by the source editor. No document-wide pixel ratio is involved.
final class MarkdownListViewport {
  static double? read(
    ListController list,
    ScrollController scroll,
    List<MarkdownBlock> blocks,
  ) {
    if (!list.isAttached || !scroll.hasClients || blocks.isEmpty) return null;
    final index = list.visibleRange?.$1;
    if (index == null || index >= blocks.length) return null;
    // ignore: invalid_use_of_visible_for_testing_member
    final top = list.getOffsetToReveal(index, 0);
    final extent = list.extentForIndex(index).$1;
    if (!top.isFinite || extent <= 0) return null;
    final fraction = ((scroll.offset - top) / extent).clamp(0.0, 1.0);
    final block = blocks[index];
    final end = index + 1 < blocks.length
        ? blocks[index + 1].range.start
        : block.range.end;
    return block.range.start + fraction * (end - block.range.start);
  }

  static void write(
    double offset,
    ListController list,
    ScrollController scroll,
    List<MarkdownBlock> blocks, {
    double alignment = 0,
  }) {
    if (!list.isAttached || !scroll.hasClients || blocks.isEmpty) return;
    var low = 0, high = blocks.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (blocks[middle].range.start <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final index = (low - 1).clamp(0, blocks.length - 1);
    final block = blocks[index];
    final end = index + 1 < blocks.length
        ? blocks[index + 1].range.start
        : block.range.end;
    final length = end - block.range.start;
    final fraction = length == 0
        ? 0.0
        : ((offset - block.range.start) / length).clamp(0.0, 1.0);
    list.jumpToItem(
      index: index,
      scrollController: scroll,
      alignment: alignment,
      rect: Rect.fromLTWH(0, list.extentForIndex(index).$1 * fraction, 1, 0),
    );
  }
}

/// Cached source line starts, shared by fixed-height desktop source positioning.
final class MarkdownSourceViewport {
  String? _source;
  List<int> _starts = [0];
  void update(String source) {
    if (source == _source) return;
    _source = source;
    _starts = [
      0,
      for (final match in RegExp(r'\r\n|\r|\n').allMatches(source)) match.end,
    ];
  }

  double offsetAtLine(double line) {
    final index = line.floor().clamp(0, _starts.length - 1);
    final end = index + 1 < _starts.length
        ? _starts[index + 1]
        : _source!.length;
    return _starts[index] +
        (line - index).clamp(0.0, 1.0) * (end - _starts[index]);
  }

  double lineAtOffset(double offset) {
    var low = 0, high = _starts.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_starts[middle] <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final index = (low - 1).clamp(0, _starts.length - 1);
    final end = index + 1 < _starts.length
        ? _starts[index + 1]
        : _source!.length;
    return index +
        (end == _starts[index]
            ? 0
            : ((offset - _starts[index]) / (end - _starts[index])).clamp(
                0.0,
                1.0,
              ));
  }
}
