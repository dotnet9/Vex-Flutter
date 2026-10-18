import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import '../core/app_theme.dart';
import 'workspace_view_model.dart';

enum WorkspacePicker { layout, typography }

class MindMapLayoutChoices extends StatelessWidget {
  const MindMapLayoutChoices({
    super.key,
    required this.vm,
    required this.width,
  });
  final WorkspaceViewModel vm;
  final double width;
  static const _sample = MindMapNode(
    id: 'root',
    title: '',
    children: [
      MindMapNode(
        id: 'a',
        title: '',
        children: [MindMapNode(id: 'a1', title: '')],
      ),
      MindMapNode(id: 'b', title: ''),
      MindMapNode(id: 'c', title: ''),
      MindMapNode(id: 'd', title: ''),
    ],
  );
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final mode in MindMapLayoutMode.values)
        _ChoiceCard(
          key: ValueKey('map-layout-${mode.name}'),
          width: (width - 8) / 2,
          height: 86,
          selected: vm.map.mode == mode,
          label: context.l10n.mapLayoutName(mode),
          onTap: () => vm.setSummary(mode: mode),
          child: Column(
            children: [
              Expanded(
                child: SizedBox.expand(
                  child: CustomPaint(
                    painter: _MapMiniature(
                      MindMapLayout.compute(_sample, mode: mode),
                      Theme.of(context).colorScheme,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.mapLayoutName(mode),
                maxLines: 1,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
    ],
  );
}

class _MapMiniature extends CustomPainter {
  const _MapMiniature(this.layout, this.colors);
  final MindMapLayout layout;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / layout.size.width,
      size.height / layout.size.height,
    );
    canvas.translate(
      (size.width - layout.size.width * scale) / 2,
      (size.height - layout.size.height * scale) / 2,
    );
    canvas.scale(scale);
    final paint = Paint()
      ..color = colors.onSurfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale;
    for (final path in layout.paths) {
      canvas.drawPath(path, paint);
    }
    paint.style = PaintingStyle.fill;
    for (final entry in layout.rects.entries) {
      paint.color = entry.key == 'root'
          ? colors.primary
          : colors.primaryContainer;
      canvas.drawRRect(
        RRect.fromRectAndRadius(entry.value, const Radius.circular(6)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MapMiniature old) =>
      old.layout != layout || old.colors != colors;
}

/// An anchored, non-modal panel: the document stays visible and interactive.
class WorkspacePickerAnchor extends StatelessWidget {
  const WorkspacePickerAnchor({
    super.key,
    required this.vm,
    required this.picker,
    required this.controller,
    required this.child,
  });
  final WorkspaceViewModel vm;
  final WorkspacePicker picker;
  final MenuController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = math.min(
      picker == WorkspacePicker.layout ? 496.0 : 438.0,
      MediaQuery.sizeOf(context).width - 24,
    );
    return MenuAnchor(
      controller: controller,
      consumeOutsideTap: false,
      alignmentOffset: const Offset(0, 6),
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): controller.close,
          },
          child: Focus(
            autofocus: true,
            child: ListenableBuilder(
              listenable: vm,
              builder: (context, _) => SizedBox(
                key: ValueKey('${picker.name}-picker'),
                width: width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height - 80,
                  ),
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                picker == WorkspacePicker.layout
                                    ? context.l10n.workspaceLayout
                                    : context.l10n.markdownTypography,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            AppCloseButton(
                              tooltip: context.l10n.closePicker,
                              onPressed: controller.close,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          picker == WorkspacePicker.layout
                              ? context.l10n.layoutHint
                              : context.l10n.typographyHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (picker == WorkspacePicker.layout)
                          LayoutChoices(vm: vm, width: width - 32)
                        else ...[
                          TypographyChoices(vm: vm, width: width - 32),
                          const SizedBox(height: 12),
                          const Divider(),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              context.l10n.compactSpacing,
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: vm.compact,
                            onChanged: (value) =>
                                vm.updateAppearance(compact: value),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      child: child,
    );
  }
}

class LayoutChoices extends StatelessWidget {
  const LayoutChoices({super.key, required this.vm, required this.width});
  final WorkspaceViewModel vm;
  final double width;

  @override
  Widget build(BuildContext context) {
    final columns = width >= 440 ? 4 : 2;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final layout in WorkspaceLayout.values.where(
          (layout) => layout.panes.length <= vm.viewport.maxPanes,
        ))
          _ChoiceCard(
            key: ValueKey('layout-${layout.name}'),
            width: (width - (columns - 1) * 8) / columns,
            height: 92,
            selected: vm.layout == layout,
            label: context.l10n.layoutName(layout),
            onTap: () => vm.setLayout(layout),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: LayoutMiniature(layout)),
                const SizedBox(height: 8),
                Text(
                  context.l10n.layoutName(layout),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 10.5),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class TypographyChoices extends StatelessWidget {
  const TypographyChoices({super.key, required this.vm, required this.width});
  final WorkspaceViewModel vm;
  final double width;

  @override
  Widget build(BuildContext context) {
    final columns = width >= 380 ? 3 : 2;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in MarkdownTypography.values)
          _ChoiceCard(
            key: ValueKey('typography-${type.name}'),
            width: (width - (columns - 1) * 8) / columns,
            height: 176,
            selected: vm.typography == type,
            label: context.l10n.typographyName(type),
            onTap: () => vm.updateAppearance(typography: type),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _TypographySample(type)),
                const SizedBox(height: 8),
                Text(
                  context.l10n.typographyName(type),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.width,
    required this.height,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });
  final double width, height;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: selected ? c.primaryContainer : c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: selected ? c.primary : c.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(9), child: child),
          ),
        ),
      ),
    );
  }
}

class LayoutMiniature extends StatelessWidget {
  const LayoutMiniature(this.layout, {super.key});
  final WorkspaceLayout layout;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget panel(String type) => Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: type == 'read' ? c.surfaceContainerLow : c.primaryContainer,
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: AppGlyph(switch (type) {
          'map' => 'map',
          'read' => 'eye',
          'source' => 'code',
          _ => 'edit',
        }, size: 11),
      ),
    );
    if (layout == WorkspaceLayout.three) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: panel('source')),
                Expanded(child: panel('read')),
              ],
            ),
          ),
          Expanded(child: panel('map')),
        ],
      );
    }
    return Row(
      children: [for (final type in layout.panes) Expanded(child: panel(type))],
    );
  }
}

class _TypographySample extends StatelessWidget {
  const _TypographySample(this.type);
  final MarkdownTypography type;
  @override
  Widget build(BuildContext context) => Theme(
    data: documentTheme(Theme.of(context)),
    child: ClipRect(
      child: FittedBox(
        alignment: Alignment.topLeft,
        fit: BoxFit.contain,
        child: SizedBox(
          width: 360,
          height: 420,
          child: ColoredBox(
            color: documentTheme(Theme.of(context)).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: IgnorePointer(
                child: SingleChildScrollView(
                  primary: false,
                  child: MarkdownReader(
                    data:
                        '# ${context.l10n.sampleHeading}\n\n## ${context.l10n.outline}\n\n### ${context.l10n.sampleHeading}\n\n#### ${context.l10n.sampleHeading}',
                    typography: type,
                    fontSize: 18,
                    selectable: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
