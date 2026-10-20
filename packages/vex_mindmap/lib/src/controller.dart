import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'style.dart';

final class MindMapViewState {
  MindMapViewState._(MindMapController controller)
    : mode = controller.mode,
      style = controller.style,
      selectedId = controller.selectedId,
      collapsed = Set.unmodifiable(controller.collapsed),
      _transformation = Matrix4.copy(controller.transformation.value),
      viewportSize = controller.viewportSize,
      fitRequested = controller.fitRequested;
  final MindMapLayoutMode mode;
  final MindMapStyle style;
  final String? selectedId;
  final Set<String> collapsed;
  final Matrix4 _transformation;
  final Size? viewportSize;
  final bool fitRequested;
}

final class MindMapController extends ChangeNotifier {
  MindMapController(MindMapNode root) : _root = root {
    _layout = MindMapLayout.compute(root);
    transformation.addListener(_transformed);
  }
  MindMapNode _root;
  late MindMapLayout _layout;
  final transformation = TransformationController();
  Size? viewportSize;
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

  /// 摘要等“根与模式一起变化”的场景一次性重排，避免 setMode+setRoot 双次 compute。
  void setRootAndMode(MindMapNode value, MindMapLayoutMode mode) {
    _mode = mode;
    final changed = value.id != _root.id;
    _root = value;
    if (changed) {
      _selected = null;
      _collapsed.clear();
    }
    _layout = MindMapLayout.compute(value, collapsed: _collapsed, mode: _mode);
    fitRequested = true;
    notifyListeners();
  }

  String? _selected;
  String? followRequestedId;

  /// Called on a chapter change, so scrolling inside a chapter preserves pan.
  void follow(String? id) {
    if (_selected == id) return;
    _selected = id;
    followRequestedId = id;
    notifyListeners();
  }

  bool fitRequested = true;
  MindMapNode get root => _root;
  MindMapLayout get layout => _layout;
  Set<String> get collapsed => Set.unmodifiable(_collapsed);
  MindMapViewState snapshotView() => MindMapViewState._(this);

  void restoreView(MindMapViewState state) {
    _mode = state.mode;
    _style = state.style;
    _selected = state.selectedId;
    _collapsed
      ..clear()
      ..addAll(state.collapsed);
    _layout = MindMapLayout.compute(root, collapsed: _collapsed, mode: _mode);
    fitRequested = state.fitRequested;
    viewportSize = state.viewportSize;
    // 恢复矩阵不再触发一次多余的监听广播，统一由末尾的单次 notify 通知。
    _suppressTransformNotify = true;
    transformation.value = Matrix4.copy(state._transformation);
    _suppressTransformNotify = false;
    notifyListeners();
  }

  String? get selectedId => _selected;
  double get scale {
    // This is a 2D transform; the unchanged Z axis is 1 even below 100% zoom.
    final matrix = transformation.value;
    return math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1]);
  }

  bool _suppressTransformNotify = false;

  void _transformed() {
    if (_suppressTransformNotify) return;
    notifyListeners();
  }

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
    viewportSize = viewport;
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
    viewportSize = viewport;
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
    viewportSize = viewport;
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

  /// Keep the same scene point at the center when a workspace pane resizes.
  void resizeViewport(Size viewport) {
    if (viewport.isEmpty || viewport == viewportSize) return;
    final previous = viewportSize;
    viewportSize = viewport;
    if (previous == null || fitRequested) return;
    final matrix = Matrix4.copy(transformation.value);
    matrix[12] += (viewport.width - previous.width) / 2;
    matrix[13] += (viewport.height - previous.height) / 2;
    transformation.value = matrix;
  }

  @override
  void dispose() {
    transformation.removeListener(_transformed);
    transformation.dispose();
    super.dispose();
  }
}
