import 'package:flutter/widgets.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

/// Chapter jumps are immediate; optional short moves own a cancellable ticker.
final class MarkdownListNavigator {
  MarkdownListNavigator({
    required TickerProvider vsync,
    required this.list,
    required this.scroll,
  }) : _animation = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 120),
       ) {
    _animation.addListener(_tick);
  }

  final ListController list;
  final ScrollController scroll;
  final AnimationController _animation;
  double _start = 0, _target = 0;
  Object? _layoutKey, _contentKey;

  /// Call before rebuilding a changed layout, while old item geometry is valid.
  /// The list resolves this anchor during layout, without a post-frame jump.
  void preservePosition(Object layoutKey, {required Object contentKey}) {
    final changed = _layoutKey != null && _layoutKey != layoutKey;
    final sameContent = identical(_contentKey, contentKey);
    _layoutKey = layoutKey;
    _contentKey = contentKey;
    if (!changed || !sameContent || !list.isAttached || !scroll.hasClients) {
      return;
    }
    final position = scroll.position;
    if (position.pixels <= position.minScrollExtent) return;
    final index = list.visibleRange?.$1;
    if (index == null) return;
    cancel();
    // Querying a reveal primes SuperSliverList's same-layout offset correction.
    // A local rect keeps the visible portion of the first block at the top.
    // ignore: invalid_use_of_visible_for_testing_member
    final top = list.getOffsetToReveal(index, 0);
    if (!top.isFinite) return;
    // ignore: invalid_use_of_visible_for_testing_member
    list.getOffsetToReveal(
      index,
      0,
      rect: Rect.fromLTWH(0, position.pixels - top, 1, 0),
    );
  }

  void reveal(int index, {bool animated = false, double alignment = .08}) {
    cancel();
    if (!list.isAttached || !scroll.hasClients) return;
    // Estimated heights must be resolved by the list's index anchor, not a
    // pixel tween that reveals one position and corrects it in later frames.
    final range = list.visibleRange;
    if (!animated ||
        range == null ||
        index < range.$1 ||
        index > range.$2 ||
        list.extentForIndex(index).$2) {
      list.jumpToItem(
        index: index,
        scrollController: scroll,
        alignment: alignment,
      );
      return;
    }
    _start = scroll.offset;
    // ignore: invalid_use_of_visible_for_testing_member
    _target = list.getOffsetToReveal(index, alignment);
    if (!_target.isFinite) return;
    _animation.forward(from: 0);
  }

  void _tick() {
    if (!list.isAttached || !scroll.hasClients) {
      cancel();
      return;
    }
    final progress = Curves.easeInOut.transform(_animation.value);
    final position = scroll.position;
    scroll.jumpTo(
      (_start + (_target - _start) * progress).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void cancel() => _animation.stop();

  void dispose() => _animation.dispose();
}
