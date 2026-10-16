import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout.dart';

final class MindMapController extends ChangeNotifier {
  MindMapController(MindMapNode root) : _root = root {
    _layout = MindMapLayout.compute(root);
    transformation.addListener(_transformed);
  }
  MindMapNode _root;
  late MindMapLayout _layout;
  final transformation = TransformationController();
  final _collapsed = <String>{};
  String? _selected;
  bool fitRequested = true;
  MindMapNode get root => _root;
  MindMapLayout get layout => _layout;
  Set<String> get collapsed => Set.unmodifiable(_collapsed);
  String? get selectedId => _selected;
  double get scale => transformation.value.getMaxScaleOnAxis();
  void _transformed() => notifyListeners();
  void setRoot(MindMapNode value) {
    final changed = value.id != _root.id;
    final next = MindMapLayout.compute(value, collapsed: _collapsed);
    _root = value;
    _layout = next;
    if (changed) {
      _selected = null;
      _collapsed.clear();
      _layout = MindMapLayout.compute(value);
      fitRequested = true;
    }
    notifyListeners();
  }

  void select(String? id) {
    _selected = id;
    notifyListeners();
  }

  void toggle(String id) {
    if (!_collapsed.add(id)) _collapsed.remove(id);
    _layout = MindMapLayout.compute(root, collapsed: _collapsed);
    notifyListeners();
  }

  void toggleAll() {
    if (_collapsed.isNotEmpty) {
      _collapsed.clear();
    } else {
      _collapsed.addAll(
        _layout.nodes.values
            .where((n) => n.children.isNotEmpty && n.id != root.id)
            .map((n) => n.id),
      );
    }
    _layout = MindMapLayout.compute(root, collapsed: _collapsed);
    fitRequested = true;
    notifyListeners();
  }

  void fit(Size viewport) {
    if (viewport.isEmpty) return;
    final factor = math
        .min(
          1.0,
          math.min(
            (viewport.width - 48) / layout.size.width,
            (viewport.height - 48) / layout.size.height,
          ),
        )
        .clamp(.15, 3.0);
    transformation.value = Matrix4.diagonal3Values(factor, factor, 1)
      ..setTranslationRaw(
        (viewport.width - layout.size.width * factor) / 2,
        (viewport.height - layout.size.height * factor) / 2,
        0,
      );
    fitRequested = false;
  }

  void zoom(double factor, Size viewport) {
    final nextScale = (scale * factor).clamp(.15, 3.0),
        ratio = nextScale / scale;
    final position = transformation.value.getTranslation();
    transformation.value = Matrix4.diagonal3Values(nextScale, nextScale, 1)
      ..setTranslationRaw(
        viewport.width / 2 + (position.x - viewport.width / 2) * ratio,
        viewport.height / 2 + (position.y - viewport.height / 2) * ratio,
        0,
      );
  }

  @override
  void dispose() {
    transformation.removeListener(_transformed);
    transformation.dispose();
    super.dispose();
  }
}
