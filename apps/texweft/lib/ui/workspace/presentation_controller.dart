import 'package:flutter/material.dart';
import 'package:texweft_mindmap/texweft_mindmap.dart';

import '../../domain/presentation.dart';

/// Presentation changes do not rebuild the hidden editing workspace.
final class PresentationController extends ChangeNotifier {
  PresentationController(this.deck, {String? headingId, this.mapMode = false}) {
    final selected = deck.slides.indexWhere(
      (slide) => headingId != null && slide.headingId == headingId,
    );
    if (selected >= 0) _page = selected;
    final root = MindMapNode(
      id: 'slide-0',
      title: deck.slides.first.title,
      children: [],
    );
    final stack = <({int level, MindMapNode node})>[(level: 0, node: root)];
    for (var i = 1; i < deck.slides.length; i++) {
      final slide = deck.slides[i];
      while (stack.length > 1 && stack.last.level >= slide.level) {
        stack.removeLast();
      }
      final node = MindMapNode(
        id: 'slide-$i',
        title: slide.title,
        children: [],
      );
      stack.last.node.children.add(node);
      stack.add((level: slide.level, node: node));
    }
    map = MindMapController(root);
  }

  final PresentationDeck deck;
  late final MindMapController map;
  Size mapViewport = Size.zero;
  bool mapMode;
  void showMap(bool value) {
    if (mapMode == value) return;
    mapMode = value;
    notifyListeners();
  }

  int _page = 0;
  double _scale = 1.5;
  bool _outline = true;
  int get page => _page;
  double get scale => _scale;
  bool get outline => _outline;
  bool get hasPrevious => page > 0;
  bool get hasNext => page + 1 < deck.slides.length;
  PresentationSlide get slide => deck.slides[page];

  void goTo(int value) {
    final next = value.clamp(0, deck.slides.length - 1);
    if (next == _page) return;
    _page = next;
    notifyListeners();
  }

  void next() => goTo(page + 1);
  void previous() => goTo(page - 1);
  void resize(double value) {
    final next = (value * 10).round().clamp(10, 25) / 10;
    if (next == _scale) return;
    _scale = next;
    notifyListeners();
  }

  void toggleOutline() {
    _outline = !_outline;
    notifyListeners();
  }

  @override
  void dispose() {
    map.dispose();
    super.dispose();
  }
}
