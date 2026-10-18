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
    this.totalSteps = 7,
  });
  final GlobalKey target;
  final int step;
  final int totalSteps;
  final String title, description;
  final VoidCallback onClose;
  final ValueChanged<int> onStep;
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
      final width = math.min(344.0, constraints.maxWidth - 32);
      final target = _target;
      var x = constraints.maxWidth - width - 24, y = 150.0;
      if (target != null) {
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
                          Text(
                            context.l10n.quickStart,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${widget.step + 1} / ${widget.totalSteps}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          AppCloseButton(onPressed: widget.onClose),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.description,
                        style: const TextStyle(fontSize: 14, height: 1.8),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          for (var i = 0; i < widget.totalSteps; i++)
                            Expanded(
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                color: i == widget.step
                                    ? colors.primary
                                    : colors.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: [
                          AppButton(
                            label: context.l10n.endGuide,
                            onPressed: widget.onClose,
                          ),
                          if (widget.step > 0)
                            AppButton(
                              label: context.l10n.previous,
                              onPressed: () => widget.onStep(widget.step - 1),
                            ),
                          AppButton(
                            label: widget.step == widget.totalSteps - 1
                                ? context.l10n.done
                                : context.l10n.next,
                            primary: true,
                            onPressed: () =>
                                widget.step == widget.totalSteps - 1
                                ? widget.onClose()
                                : widget.onStep(widget.step + 1),
                          ),
                        ],
                      ),
                    ],
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
