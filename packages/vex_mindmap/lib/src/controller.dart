import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'style.dart';

final class MindMapController extends ChangeNotifier {
  MindMapController(MindMapNode root) : _root = root {
    _layout = MindMapLayout.compute(root);
    transformation.addListener(_transformed);
  }
  MindMapNode _root;
  late MindMapLayout _layout;
  final transformation = TransformationController();
  final _collapsed = <String>{};
  MindMapLayoutMode _mode = MindMapLayoutMode.right;
  MindMapLayoutMode get mode => _mode;
  MindMapStyle _style = MindMapStyle.quiet;
  MindMapStyle get style => _style;
  void setStyle(MindMapStyle value) {
    if (_style == value) return;
    _style = value;
    notifyListeners();
  }

  void setMode(MindMapLayoutMode value) {
    if (_mode == value) return;
    _mode = value;
    _layout = MindMapLayout.compute(root, collapsed: _collapsed, mode: _mode);
    fitRequested = true;
    notifyListeners();
  }

  String? _selected;
  bool fitRequested = true;
  MindMapNode get root => _root;
  MindMapLayout get layout => _layout;
  Set<String> get collapsed => Set.unmodifiable(_collapsed);
  String? get selectedId => _selected;
  double get scale {
    // This is a 2D transform; the unchanged Z axis is 1 even below 100% zoom.
    final matrix = transformation.value;
    return math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1]);
  }

  void _transformed() => notifyListeners();
  void setRoot(MindMapNode value) {
    final changed = value.id != _root.id;
    _root = value;
    if (changed) {
      _selected = null;
      _collapsed.clear();
      fitRequested = true;
    }
    _layout = MindMapLayout.compute(value, collapsed: _collapsed, mode: _mode);
    notifyListeners();
  }

  void select(String? id) {
    _selected = id;
    notifyListeners();
  }

  void toggle(String id) {
    if (!_collapsed.add(id)) _collapsed.remove(id);
    _layout = MindMapLayout.compute(root, collapsed: _collapsed, mode: _mode);
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
    _layout = MindMapLayout.compute(root, collapsed: _collapsed, mode: _mode);
    fitRequested = true;
    notifyListeners();
  }

  double _fitScale(Size viewport) => math
      .min(
        1.0,
        math.min(
          (viewport.width - 48) / layout.size.width,
          (viewport.height - 48) / layout.size.height,
        ),
      )
      .clamp(.000001, 3.0);

  /// Keep the entire tree reachable even when a large map needs less than 15%.
  double minimumScaleFor(Size viewport) => math.min(.15, _fitScale(viewport));

  void fit(Size viewport) {
    if (viewport.isEmpty) return;
    final factor = _fitScale(viewport);
    transformation.value = Matrix4.diagonal3Values(factor, factor, 1)
      ..setTranslationRaw(
        (viewport.width - layout.size.width * factor) / 2,
        (viewport.height - layout.size.height * factor) / 2,
        0,
      );
    fitRequested = false;
  }

  /// Reveal collapsed ancestors and center a node at a readable scale.
  void focusNode(String id, Size viewport, {double scale = 1}) {
    if (viewport.isEmpty) return;
    final path = <String>[];
    bool locate(MindMapNode node) {
      path.add(node.id);
      if (node.id == id) return true;
      for (final child in node.children) {
        if (locate(child)) return true;
      }
      path.removeLast();
      return false;
    }

    if (!locate(root)) return;
    var revealed = false;
    for (final ancestor in path.take(path.length - 1)) {
      revealed = _collapsed.remove(ancestor) || revealed;
    }
    if (revealed) {
      _layout = MindMapLayout.compute(root, collapsed: _collapsed, mode: _mode);
    }
    final target = layout.rects[id];
    if (target == null) return;
    _selected = id;
    fitRequested = false;
    final factor = scale.clamp(.15, 3.0);
    transformation.value = Matrix4.diagonal3Values(factor, factor, 1)
      ..setTranslationRaw(
        viewport.width / 2 - target.center.dx * factor,
        viewport.height / 2 - target.center.dy * factor,
        0,
      );
  }

  void zoom(double factor, Size viewport) {
    final nextScale = (scale * factor).clamp(minimumScaleFor(viewport), 3.0),
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
