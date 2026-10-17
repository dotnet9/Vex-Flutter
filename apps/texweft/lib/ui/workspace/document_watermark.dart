import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/export_preferences.dart';

class DocumentWatermark extends StatelessWidget {
  const DocumentWatermark({
    super.key,
    required this.preferences,
    required this.child,
  });
  final WatermarkPreferences preferences;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (preferences.preview && preferences.visible)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                key: const ValueKey('document-watermark'),
                painter: DocumentWatermarkPainter(
                  preferences,
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xff93c6bb)
                      : const Color(0xff24766b),
                  Directionality.of(context),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class DocumentWatermarkPainter extends CustomPainter {
  DocumentWatermarkPainter(this.preferences, this.color, this.direction);
  final WatermarkPreferences preferences;
  final Color color;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: preferences.text,
        style: TextStyle(
          fontSize: 21,
          letterSpacing: 0,
          color: color.withValues(alpha: preferences.opacity),
        ),
      ),
      textDirection: direction,
    )..layout();
    final scale = painter.width > 235 ? 235 / painter.width : 1.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 90.0; y < size.height + 90; y += 180) {
      for (var x = 140.0; x < size.width + 140; x += 280) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-25 * math.pi / 180);
        canvas.scale(scale);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      }
    }
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(DocumentWatermarkPainter oldDelegate) =>
      preferences != oldDelegate.preferences ||
      color != oldDelegate.color ||
      direction != oldDelegate.direction;
}
