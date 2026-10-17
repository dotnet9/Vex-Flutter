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
  });
  final GlobalKey target;
  final int step;
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
  void _measure() {
    final box = _root.currentContext?.findRenderObject();
    final target = widget.target.currentContext?.findRenderObject();
    final card = _card.currentContext?.findRenderObject();
    if (box is! RenderBox || target is! RenderBox || !target.hasSize) return;
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
        if (target.width < constraints.maxWidth * .7 &&
            target.left > width + 40) {
          x = target.left - width - 24;
          y = target.top + 32;
        } else {
          x = target.left + 24;
          y = target.height < 120 ? target.bottom + 28 : target.top + 64;
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
                key: const ValueKey('guide-arrow'),
                painter: _GuidePainter(target, cardRect, colors.primary),
              ),
            ),
          ),
          Positioned(
            left: x,
            top: y,
            width: width,
            child: Material(
              key: _card,
              elevation: 12,
              color: colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                            '${widget.step + 1} / 6',
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
                          for (var i = 0; i < 6; i++)
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
                            label: widget.step == 5
                                ? context.l10n.done
                                : context.l10n.next,
                            primary: true,
                            onPressed: () => widget.step == 5
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
  _GuidePainter(this.target, this.card, this.accent);
  final Rect? target;
  final Rect card;
  final Color accent;
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
    // Choose the closest card edge and target boundary. This remains stable at
    // arbitrary window sizes and does not depend on screenshot coordinates.
    final center = rect.center;
    final start = Offset(
      center.dx.clamp(card.left + 14, card.right - 14),
      center.dy < card.top ? card.top : card.bottom,
    );
    var end = Offset(
      start.dx.clamp(rect.left + 8, rect.right - 8),
      start.dy < rect.top ? rect.top : rect.bottom,
    );
    if (card.right < rect.left || card.left > rect.right) {
      end = Offset(
        card.right < rect.left ? rect.left : rect.right,
        card.center.dy.clamp(rect.top + 8, rect.bottom - 8),
      );
    }
    var from = start;
    if (card.right < rect.left || card.left > rect.right) {
      from = Offset(
        card.right < rect.left ? card.right : card.left,
        end.dy.clamp(card.top + 14, card.bottom - 14),
      );
    }
    if (card.overlaps(rect)) {
      end = Offset(rect.right - 16, rect.top + 12);
      from = Offset(card.right - 18, card.top);
    }
    final direction = (end - from) / math.max(1, (end - from).distance);
    end -= direction * 6;
    canvas.drawLine(
      from,
      end,
      Paint()
        ..color = accent
        ..strokeWidth = 2.5,
    );
    final normal = Offset(-direction.dy, direction.dx);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          (end - direction * 12 + normal * 5).dx,
          (end - direction * 12 + normal * 5).dy,
        )
        ..lineTo(
          (end - direction * 12 - normal * 5).dx,
          (end - direction * 12 - normal * 5).dy,
        )
        ..close(),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      target != old.target || card != old.card || accent != old.accent;
}
