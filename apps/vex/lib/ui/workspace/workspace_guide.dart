import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';

/// The target remains interactive; only the card consumes pointer events.
class WorkspaceGuide extends StatefulWidget {
  const WorkspaceGuide({
    super.key,
    required this.target,
    required this.step,
    required this.title,
    required this.description,
    required this.onClose,
    required this.onStep,
    this.totalSteps = 9,
    this.stage,
    this.liveMessage,
    this.resultTitle,
    this.result,
    this.running = false,
    this.paused = false,
    this.completed = false,
    this.onReplay,
    this.onSkip,
    this.onContinue,
    this.showCard = true,
  });
  final GlobalKey target;
  final int step;
  final int totalSteps;
  final String title, description;
  final String? stage, liveMessage, resultTitle, result;
  final bool running, paused, completed;
  final VoidCallback onClose;
  final ValueChanged<int> onStep;
  final VoidCallback? onReplay, onSkip, onContinue;
  /// Key moments keep the card visible; ordinary automated actions use only
  /// the cut-out and a short hint next to the highlighted target.
  final bool showCard;
  @override
  State<WorkspaceGuide> createState() => _WorkspaceGuideState();
}

class _WorkspaceGuideState extends State<WorkspaceGuide> {
  final _root = GlobalKey(), _card = GlobalKey();
  Rect? _target;
  double _cardHeight = 280;
  @override
  void didUpdateWidget(WorkspaceGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target || oldWidget.step != widget.step) {
      _target = null;
    }
  }

  void _measure() {
    final box = _root.currentContext?.findRenderObject();
    final target = widget.target.currentContext?.findRenderObject();
    final card = _card.currentContext?.findRenderObject();
    if (box is! RenderBox || target is! RenderBox || !target.hasSize) {
      if (_target != null) setState(() => _target = null);
      return;
    }
    final origin = box.globalToLocal(target.localToGlobal(Offset.zero));
    final bounds = (origin & target.size).intersect(Offset.zero & box.size);
    final height = card is RenderBox && card.hasSize
        ? card.size.height
        : _cardHeight;
    if (_target != bounds || height != _cardHeight) {
      setState(() {
        _target = bounds;
        _cardHeight = height;
      });
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measure();
      });
      final width = math.min(
        widget.step < 0 ? 408.0 : widget.completed ? 480.0 : 376.0,
        constraints.maxWidth - 32,
      );
      final target = _target;
      var x = constraints.maxWidth - width - 24, y = 150.0;
      if (widget.step < 0) {
        x = (constraints.maxWidth - width) / 2;
        y = (constraints.maxHeight - _cardHeight) / 2;
      } else if (target != null) {
        if (constraints.maxWidth - target.right >= width + 26) {
          x = target.right + 10;
          y = target.top;
        } else if (target.left >= width + 26) {
          x = target.left - width - 10;
          y = target.top;
        } else if (constraints.maxHeight - target.bottom >= _cardHeight + 26) {
          x = target.center.dx - width / 2;
          y = target.bottom + 10;
        } else if (target.top >= _cardHeight + 26) {
          x = target.center.dx - width / 2;
          y = target.top - _cardHeight - 10;
        } else {
          x = target.left + 12;
          y = target.top + 18;
        }
      }
      x = x.clamp(16, math.max(16, constraints.maxWidth - width - 16));
      y = y.clamp(16, math.max(16, constraints.maxHeight - _cardHeight - 16));
      final cardRect = Rect.fromLTWH(x, y, width, _cardHeight);
      final colors = Theme.of(context).colorScheme;
      final cardVisible = !(widget.running && !widget.showCard);
      var hintX = target == null ? 16.0 : target.center.dx - 150;
      var hintY = target == null ? 16.0 : target.top - 44;
      if (target != null && hintY < 16) hintY = target.bottom + 12;
      hintX = hintX.clamp(16, math.max(16, constraints.maxWidth - 300));
      hintY = hintY.clamp(16, math.max(16, constraints.maxHeight - 44));
      return Stack(
        key: _root,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('guide-pointer'),
                painter: _GuidePainter(
                  target,
                  cardRect,
                  colors.primary,
                  colors.surfaceContainerLow,
                  colors.outlineVariant,
                ),
              ),
            ),
          ),
          if (!cardVisible && widget.liveMessage != null)
            Positioned(
              left: hintX,
              top: hintY,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .28),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Text(
                    widget.liveMessage!,
                    style: const TextStyle(fontSize: 12, height: 1.45),
                  ),
                ),
              ),
            ),
          if (cardVisible)
            AnimatedPositioned(
            key: const ValueKey('guide-card'),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            left: x,
            top: y,
            width: width,
            child: Material(
              key: _card,
              elevation: 12,
              color: colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight - 32,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                          AppCloseButton(onPressed: widget.onClose),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (widget.running && widget.showCard &&
                          widget.liveMessage != null)
                        Text(
                          widget.liveMessage!,
                          style: const TextStyle(fontSize: 14, height: 1.75),
                        )
                      else if (widget.completed && widget.resultTitle != null) ...[
                        Text(
                          widget.resultTitle!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.result ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.75,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ] else ...[
                        Text(
                          widget.description,
                          style: const TextStyle(fontSize: 14, height: 1.75),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _GuideActions(
                        step: widget.step,
                        totalSteps: widget.totalSteps,
                        running: widget.running,
                        paused: widget.paused,
                        completed: widget.completed,
                        onClose: widget.onClose,
                        onStep: widget.onStep,
                        onSkip: widget.onSkip,
                        onContinue: widget.onContinue,
                      ),
                    ],
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
}

class _GuideActions extends StatelessWidget {
  const _GuideActions({
    required this.step,
    required this.totalSteps,
    required this.running,
    required this.paused,
    required this.completed,
    required this.onClose,
    required this.onStep,
    this.onSkip,
    this.onContinue,
  });
  final int step, totalSteps;
  final bool running, paused, completed;
  final VoidCallback onClose;
  final ValueChanged<int> onStep;
  final VoidCallback? onSkip, onContinue;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    if (step < 0) {
      left.add(AppButton(label: '先不看', onPressed: onClose));
      right.add(
        AppButton(
          label: '开始吧  →',
          primary: true,
          onPressed: () => onStep(0),
        ),
      );
    } else {
      if (running && onSkip != null) {
        left.add(AppButton(label: '跳过本段', onPressed: onSkip));
      }
      if ((paused || !running) && step > 0) {
        right.add(
          AppButton(
            label: '← ${context.l10n.previous}',
            onPressed: () => onStep(step - 1),
          ),
        );
      }
      final finalStep = totalSteps - 2;
      final isFinal = completed && step == finalStep;
      right.add(
        AppButton(
          label: running
              ? paused
                    ? '继续  →'
                    : '演示中…'
              : isFinal
              ? '开始自己的写作  →'
              : '下一步  →',
          primary: !running || paused,
          onPressed: running
              ? paused
                    ? onContinue
                    : null
              : isFinal
              ? onClose
              : () => onStep(step + 1),
        ),
      );
    }

    Widget group(List<Widget> children) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          children[i],
        ],
      ],
    );

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: group(left),
            ),
          ),
          // 开场算第 1 步；八个幕依次为 2/9-9/9，与原型一致。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: IgnorePointer(
              child: Text(
                '${step < 0 ? 1 : step + 2}/$totalSteps',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: group(right),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(
    this.target,
    this.card,
    this.accent,
    this.surface,
    this.outline,
  );
  final Rect? target;
  final Rect card;
  final Color accent, surface, outline;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = target;
    if (rect == null || rect.isEmpty) return;
    final area = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(7),
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(area);
    canvas.drawPath(mask, Paint()..color = const Color(0x48101e19));
    canvas.drawRRect(
      area,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final horizontal = rect.right <= card.left || rect.left >= card.right;
    final base = horizontal
        ? Offset(
            rect.right <= card.left ? card.left : card.right,
            rect.center.dy.clamp(card.top + 20, card.bottom - 20),
          )
        : Offset(
            rect.center.dx.clamp(card.left + 20, card.right - 20),
            rect.top >= card.bottom ? card.bottom : card.top,
          );
    final direction = horizontal
        ? Offset(rect.right <= card.left ? -1 : 1, 0)
        : Offset(0, rect.top >= card.bottom ? 1 : -1);
    final normal = Offset(-direction.dy, direction.dx) * 7;
    final triangle = Path()
      ..moveTo((base + normal).dx, (base + normal).dy)
      ..lineTo((base + direction * 8).dx, (base + direction * 8).dy)
      ..lineTo((base - normal).dx, (base - normal).dy);
    canvas.drawPath(triangle, Paint()..color = surface);
    canvas.drawPath(
      triangle,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      target != old.target ||
      card != old.card ||
      accent != old.accent ||
      surface != old.surface ||
      outline != old.outline;
}
