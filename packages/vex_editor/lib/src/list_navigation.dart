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
