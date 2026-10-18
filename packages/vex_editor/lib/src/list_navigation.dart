import 'package:flutter/widgets.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

/// Owns the animation so a new jump, user input or disposal can cancel it.
final class MarkdownListNavigator {
  MarkdownListNavigator({
    required TickerProvider vsync,
    required this.list,
    required this.scroll,
  }) : _animation = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 200),
       ) {
    _animation.addListener(_tick);
  }

  final ListController list;
  final ScrollController scroll;
  final AnimationController _animation;
  int _index = 0;
  double _start = 0, _alignment = .08;

  void reveal(int index, {bool animated = true, double alignment = .08}) {
    cancel();
    if (!list.isAttached || !scroll.hasClients) return;
    if (!animated) {
      list.jumpToItem(
        index: index,
        scrollController: scroll,
        alignment: alignment,
      );
      return;
    }
    _index = index;
    _alignment = alignment;
    _start = scroll.offset;
    // A distant chapter should not build every intermediate viewport just to
    // animate past it. Land nearby, then animate the last part of the journey.
    // ignore: invalid_use_of_visible_for_testing_member
    final target = list.getOffsetToReveal(index, alignment);
    final position = scroll.position;
    final distance = target - _start;
    if (target.isFinite && distance.abs() > position.viewportDimension * 3) {
      _start = (target - distance.sign * position.viewportDimension * .6).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      scroll.jumpTo(_start);
    }
    _animation.forward(from: 0);
  }

  void _tick() {
    if (!list.isAttached || !scroll.hasClients) {
      cancel();
      return;
    }
    // The package's animateToItem owns an uncancellable ticker that can outlive
    // its ScrollPosition. Keep its offset calculation but own the ticker here.
    // ignore: invalid_use_of_visible_for_testing_member
    final target = list.getOffsetToReveal(_index, _alignment);
    if (!target.isFinite) {
      cancel();
      return;
    }
    final progress = Curves.easeInOut.transform(_animation.value);
    final position = scroll.position;
    scroll.jumpTo(
      (_start + (target - _start) * progress).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void cancel() => _animation.stop();

  void dispose() => _animation.dispose();
}
