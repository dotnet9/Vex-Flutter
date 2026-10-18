import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import 'markdown_preferences.dart';
import 'selection_projection.dart';

/// One laid-out block, shared by hit testing and selection painting. Coordinates
/// come from Flutter's actual paragraphs, including wrapping and font fallback.
final class MarkdownSelectionGeometry {
  MarkdownSelectionGeometry({
    required this.key,
    required this.start,
    required this.raw,
    required this.kind,
    required this.preferences,
    this.literalStart,
    this.literalText,
    this.atomic = false,
  });
  final GlobalKey key;
  final int start;
  final String raw;
  final MarkdownBlockKind kind;
  final MarkdownPreferences preferences;
  final int? literalStart;
  final String? literalText;
  final bool atomic;
  late final projection = literalText == null
      ? MarkdownSelectionProjection.block(raw, kind, preferences)
      : MarkdownSelectionProjection.literal(literalText!, start: literalStart!);
  RenderBox? get box {
    final render = key.currentContext?.findRenderObject();
    return render is RenderBox && render.attached && render.hasSize
        ? render
        : null;
  }

  List<_TextRun> _runs() {
    final root = box;
    if (root == null || atomic) return [];
    final result = <_TextRun>[];
    var cursor = 0;
    void visit(RenderObject object) {
      if ((object is RenderOpacity && object.opacity == 0) ||
          (object is RenderAnimatedOpacity && object.opacity.value == 0) ||
          (object is RenderOffstage && object.offstage)) {
        return;
      }
      if (object is RenderParagraph || object is RenderEditable) {
        final text = object is RenderParagraph
            ? object.text.toPlainText(includeSemanticsLabels: false)
            : (object as RenderEditable).text?.toPlainText(
                    includeSemanticsLabels: false,
                  ) ??
                  '';
        if (text.isEmpty) return;
        final at = projection.text.indexOf(text, cursor);
        if (at >= 0) {
          final chars = projection.characters.sublist(at, at + text.length);
          result.add(_TextRun(object as RenderBox, chars, text));
          cursor = at + text.length;
        } else if (object is RenderEditable) {
          final literal = MarkdownSelectionProjection.literal(raw);
          final from = cursor == 0 ? 0 : projection.characters[cursor - 1].end;
          final offset = literal.text.indexOf(text, from);
          if (offset >= 0) {
            result.add(
              _TextRun(
                object,
                literal.characters.sublist(offset, offset + text.length),
                text,
              ),
            );
            final next = projection.characters.indexWhere(
              (c) => c.start >= offset + text.length,
            );
            cursor = next < 0 ? projection.text.length : next;
          }
        }
        return;
      }
      object.visitChildren(visit);
    }

    root.visitChildren(visit);
    return result;
  }

  int hit(Offset global) {
    final root = box;
    if (root == null) return start;
    final candidates = _runs();
    if (candidates.isEmpty) {
      return global.dy < root.localToGlobal(root.size.center(Offset.zero)).dy
          ? start
          : start + raw.length;
    }
    candidates.sort((a, b) => a.distance(global).compareTo(b.distance(global)));
    final run = candidates.first;
    final local = run.box.globalToLocal(global);
    final offset = run.box is RenderParagraph
        ? (run.box as RenderParagraph).getPositionForOffset(local).offset
        : (run.box as RenderEditable).getPositionForPoint(global).offset;
    return start +
        (offset >= run.characters.length
            ? run.characters.last.end
            : run.characters[offset.clamp(0, run.characters.length - 1)].start);
  }

  TextSelection wordAt(Offset global) {
    final runs = _runs()
      ..sort((a, b) => a.distance(global).compareTo(b.distance(global)));
    if (runs.isEmpty) {
      return TextSelection(baseOffset: start, extentOffset: start + raw.length);
    }
    final run = runs.first;
    final position = run.box is RenderParagraph
        ? (run.box as RenderParagraph).getPositionForOffset(
            run.box.globalToLocal(global),
          )
        : (run.box as RenderEditable).getPositionForPoint(global);
    final word = run.box is RenderParagraph
        ? (run.box as RenderParagraph).getWordBoundary(position)
        : (run.box as RenderEditable).getWordBoundary(position);
    final from = word.start.clamp(0, run.characters.length - 1);
    final to = (word.end - 1).clamp(from, run.characters.length - 1);
    return TextSelection(
      baseOffset: start + run.characters[from].start,
      extentOffset: start + run.characters[to].end,
    );
  }

  bool containsText(Offset global) {
    for (final run in _runs()) {
      final selection = TextSelection(
        baseOffset: 0,
        extentOffset: run.characters.length,
      );
      final boxes = run.box is RenderParagraph
          ? (run.box as RenderParagraph).getBoxesForSelection(selection)
          : (run.box as RenderEditable).getBoxesForSelection(selection);
      final local = run.box.globalToLocal(global);
      if (boxes.any((box) => box.toRect().inflate(2).contains(local))) {
        return true;
      }
    }
    return false;
  }

  MarkdownSelectionEndpoint? endpoint(int sourceOffset, {required bool end}) {
    final root = box;
    if (root == null) return null;
    final runs = _runs();
    if (runs.isEmpty) {
      return MarkdownSelectionEndpoint(
        root.localToGlobal(
          end ? root.size.bottomRight(Offset.zero) : Offset.zero,
        ),
        24,
        TextDirection.ltr,
      );
    }
    _TextRun? nearest;
    var index = 0, distance = raw.length + 1;
    for (final run in runs) {
      for (var i = 0; i < run.characters.length; i++) {
        final char = run.characters[i];
        final delta = (start + (end ? char.end : char.start) - sourceOffset)
            .abs();
        if (delta < distance) {
          nearest = run;
          index = i;
          distance = delta;
        }
      }
    }
    if (nearest == null) return null;
    final boundary = CharacterBoundary(nearest.text);
    final selected = TextSelection(
      baseOffset: boundary.getLeadingTextBoundaryAt(index) ?? index,
      extentOffset: boundary.getTrailingTextBoundaryAt(index) ?? index + 1,
    );
    final boxes = nearest.box is RenderParagraph
        ? (nearest.box as RenderParagraph).getBoxesForSelection(selected)
        : (nearest.box as RenderEditable).getBoxesForSelection(selected);
    if (boxes.isEmpty) return null;
    final edge = end ? boxes.last : boxes.first;
    final x = end ? edge.end : edge.start;
    return MarkdownSelectionEndpoint(
      nearest.box.localToGlobal(Offset(x, edge.bottom)),
      edge.bottom - edge.top,
      edge.direction,
    );
  }

  List<Rect> selectionRects(TextSelection selection) {
    final root = box;
    if (root == null ||
        selection.isCollapsed ||
        selection.start >= start + raw.length ||
        selection.end <= start) {
      return [];
    }
    final candidates = _runs();
    if (candidates.isEmpty) return [Offset.zero & root.size];
    final result = <Rect>[];
    for (final run in candidates) {
      final from = run.characters.indexWhere(
        (c) => start + c.end > selection.start,
      );
      final to = run.characters.lastIndexWhere(
        (c) => start + c.start < selection.end,
      );
      if (from < 0 || to < from) continue;
      final local = TextSelection(baseOffset: from, extentOffset: to + 1);
      final boxes = run.box is RenderParagraph
          ? (run.box as RenderParagraph).getBoxesForSelection(local)
          : (run.box as RenderEditable).getBoxesForSelection(local);
      final offset = root.globalToLocal(run.box.localToGlobal(Offset.zero));
      result.addAll(boxes.map((box) => box.toRect().shift(offset)));
    }
    return result;
  }
}

final class MarkdownSelectionEndpoint {
  const MarkdownSelectionEndpoint(this.point, this.height, this.direction);
  final Offset point;
  final double height;
  final TextDirection direction;
}

final class _TextRun {
  _TextRun(this.box, this.characters, this.text);
  final RenderBox box;
  final List<SourceRange> characters;
  final String text;
  double distance(Offset global) {
    final local = box.globalToLocal(global);
    final dx = local.dx < 0
        ? -local.dx
        : (local.dx - box.size.width).clamp(0, double.infinity);
    final dy = local.dy < 0
        ? -local.dy
        : (local.dy - box.size.height).clamp(0, double.infinity);
    return (dy * dy * 100 + dx * dx).toDouble();
  }
}

final class MarkdownSelectionPainter extends CustomPainter {
  MarkdownSelectionPainter(this.geometry, this.selection, this.color);
  final MarkdownSelectionGeometry geometry;
  final TextSelection selection;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final rect in geometry.selectionRects(selection)) {
      canvas.drawRect(rect, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MarkdownSelectionPainter oldDelegate) => true;
}
