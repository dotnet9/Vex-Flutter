import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'controller.dart';

/// Paint search feedback over already laid-out text, without reparsing Markdown
/// or changing the reading selection. Only the active result block has a term.
class MarkdownSearchHighlight extends SingleChildRenderObjectWidget {
  const MarkdownSearchHighlight({
    super.key,
    required this.match,
    required super.child,
  });
  final MarkdownSearchMatch? match;

  /// Refine a virtual-list jump using the actual rendered text geometry.
  /// Markdown markers and link destinations make source fractions approximate.
  static void reveal(GlobalKey key) {
    final context = key.currentContext;
    final render = context?.findRenderObject();
    if (context == null || render is! _SearchHighlight) return;
    final boxes = render.matchBoxes();
    final viewport = RenderAbstractViewport.maybeOf(render);
    final position = Scrollable.maybeOf(context)?.position;
    if (boxes.isEmpty || viewport == null || position == null) return;
    final target = viewport
        .getOffsetToReveal(render, .08, rect: boxes.first)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((position.pixels - target).abs() > .5) position.jumpTo(target);
  }

  @override
  RenderObject createRenderObject(BuildContext context) => _SearchHighlight(
    match,
    Theme.of(context).colorScheme.primary.withValues(alpha: .24),
  );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _SearchHighlight).update(
      match,
      Theme.of(context).colorScheme.primary.withValues(alpha: .24),
    );
  }
}

class _SearchHighlight extends RenderProxyBox {
  _SearchHighlight(this.match, this.color);
  MarkdownSearchMatch? match;
  Color color;
  void update(MarkdownSearchMatch? value, Color ink) {
    if (match?.text == value?.text &&
        match?.occurrence == value?.occurrence &&
        color == ink) {
      return;
    }
    match = value;
    color = ink;
    markNeedsPaint();
  }

  List<Rect> matchBoxes() {
    final query = match?.text;
    if (query == null || query.isEmpty || query.length > 4096) return const [];
    RenderParagraph? paragraph;
    var matchStart = 0, seen = 0;
    var found = false;
    void visit(RenderObject object) {
      if (found) return;
      if (object is RenderParagraph && object.hasSize) {
        final text = object.text.toPlainText(includeSemanticsLabels: false);
        var start = text.indexOf(query);
        while (start >= 0) {
          paragraph = object;
          matchStart = start;
          if (seen++ == match!.occurrence) {
            found = true;
            return;
          }
          start = text.indexOf(query, start + query.length);
        }
      } else {
        object.visitChildren(visit);
      }
    }

    if (child != null) visit(child!);
    final target = paragraph;
    if (target == null) return const [];
    return [
      for (final box in target.getBoxesForSelection(
        TextSelection(
          baseOffset: matchStart,
          extentOffset: matchStart + query.length,
        ),
      ))
        MatrixUtils.transformRect(target.getTransformTo(this), box.toRect()),
    ];
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (match == null) return;
    final paint = Paint()..color = color;
    for (final rect in matchBoxes()) {
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.shift(offset).inflate(1),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }
}
