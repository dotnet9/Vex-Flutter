import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mermaid_core/mermaid_core.dart' as core;
import 'package:mermaid_flutter/mermaid_flutter.dart';

import 'labels.dart';

/// Shared renderer for inline diagrams and self-contained exports. Never
/// executes Mermaid click links, scripts, or external resource requests.
abstract final class MarkdownMermaidRenderer {
  static core.RenderScene scene(String source, ColorScheme colors) {
    if (source.length > 65536 || '\n'.allMatches(source).length > 1000) {
      throw const FormatException('Mermaid source exceeds the rendering limit');
    }
    final result = core.Mermaid(
      measurer: const FlutterTextMeasurer(),
      theme: MaterialMermaidTheme.fromColorScheme(colors),
    ).render(source);
    final size = result.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        size.width > 32768 ||
        size.height > 32768 ||
        size.width * size.height > 100000000) {
      throw const FormatException(
        'Mermaid diagram exceeds the rendering limit',
      );
    }
    core.SceneNode stripLinks(core.SceneNode node) => node is core.SceneGroup
        ? core.SceneGroup(
            children: node.children.map(stripLinks).toList(),
            id: node.id,
            role: node.role,
            semanticLabel: node.semanticLabel,
            tooltip: node.tooltip,
            edge: node.edge,
          )
        : node;
    return core.RenderScene(
      size: result.size,
      background: result.background,
      nodes: result.nodes.map(stripLinks).toList(),
    );
  }

  static String svg(String source, ColorScheme colors) =>
      core.renderSceneToSvg(scene(source, colors));

  static Future<Uint8List> png(String source, ColorScheme colors) {
    final result = scene(source, colors);
    final ratio = math.min(
      2.0,
      8192 / math.max(result.size.width, result.size.height),
    );
    return renderSceneToPng(result, pixelRatio: ratio);
  }
}

/// A stable diagram block: the source unfolds above the persistent preview.
class MarkdownMermaidBlock extends StatefulWidget {
  const MarkdownMermaidBlock({
    super.key,
    required this.source,
    this.sourceEditor,
    this.onEdit,
    this.labels = const MarkdownEditorLabels(),
    this.composing = false,
    this.tapGroup,
  });
  final String source;
  final Widget? sourceEditor;
  final VoidCallback? onEdit;
  final MarkdownEditorLabels labels;
  final bool composing;
  final Object? tapGroup;

  @override
  State<MarkdownMermaidBlock> createState() => _MarkdownMermaidBlockState();
}

class _MarkdownMermaidBlockState extends State<MarkdownMermaidBlock> {
  core.RenderScene? _scene;
  ColorScheme? _colors;
  String? _rendered;
  Object? _error;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = Theme.of(context).colorScheme;
    if (_colors != colors) {
      _colors = colors;
      _render();
    }
  }

  @override
  void didUpdateWidget(covariant MarkdownMermaidBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.composing != widget.composing ||
        oldWidget.sourceEditor != null && widget.sourceEditor == null) {
      _timer?.cancel();
      if (widget.composing) return;
      if (widget.sourceEditor == null) {
        _render();
      } else {
        _timer = Timer(const Duration(milliseconds: 240), () {
          if (mounted) setState(_render);
        });
      }
    }
  }

  void _render() {
    _timer?.cancel();
    _timer = null;
    if (_colors == null || widget.composing) return;
    try {
      _scene = MarkdownMermaidRenderer.scene(widget.source, _colors!);
      _error = null;
    } catch (error) {
      _error = error;
    }
    _rendered = widget.source;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme, scene = _scene;
    final preview = Semantics(
      label: widget.labels.diagramPreview,
      image: true,
      child: Container(
        key: const ValueKey('mermaid-preview'),
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(22),
        alignment: Alignment.center,
        child: scene == null
            ? Text(
                widget.labels.diagramUnavailable,
                style: TextStyle(color: c.onSurfaceVariant),
              )
            : Opacity(
                opacity: _error == null ? 1 : .35,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.min(
                      scene.size.width,
                      constraints.maxWidth,
                    );
                    return SizedBox(
                      width: width,
                      height: width * scene.size.height / scene.size.width,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: CustomPaint(
                          painter: ScenePainter(scene),
                          size: Size(scene.size.width, scene.size.height),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
    final block = Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Builder(
            builder: (context) {
              final source = widget.sourceEditor == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      key: const ValueKey('mermaid-source'),
                      constraints: const BoxConstraints(
                        minHeight: 128,
                        maxHeight: 360,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceContainerLow,
                        border: Border(
                          bottom: BorderSide(color: c.outlineVariant),
                        ),
                      ),
                      child: Semantics(
                        label: widget.labels.diagramSource,
                        child: widget.sourceEditor,
                      ),
                    );
              if (MediaQuery.disableAnimationsOf(context)) return source;
              return AnimatedSize(
                alignment: Alignment.topCenter,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: source,
              );
            },
          ),
          if (_rendered != widget.source && !widget.composing)
            LinearProgressIndicator(
              minHeight: 2,
              semanticsLabel: widget.labels.diagramPreview,
            ),
          if (widget.onEdit == null || widget.sourceEditor != null)
            preview
          else
            FocusableActionDetector(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    widget.onEdit!();
                    return null;
                  },
                ),
              },
              mouseCursor: SystemMouseCursors.click,
              child: Semantics(
                button: true,
                label: widget.labels.diagramSource,
                onTap: widget.onEdit,
                child: GestureDetector(onTap: widget.onEdit, child: preview),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Semantics(
                liveRegion: true,
                child: Tooltip(
                  message: _error.toString(),
                  child: Text(
                    widget.labels.diagramError,
                    key: const ValueKey('mermaid-error'),
                    style: TextStyle(color: c.error, fontSize: 13, height: 1.6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return widget.tapGroup == null
        ? block
        : TextFieldTapRegion(groupId: widget.tapGroup!, child: block);
  }
}
