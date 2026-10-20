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

enum WorkspacePicker { layout, typography, map }

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
      MindMapNode(
        id: 'b',
        title: '',
        children: [MindMapNode(id: 'b1', title: '')],
      ),
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
  const _MapMiniature(
    this.layout,
    this.colors, [
    this.style = MindMapStyle.quiet,
  ]);
  final MindMapLayout layout;
  final ColorScheme colors;
  final MindMapStyle style;
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
      final tokens = MindMapNodeStyle.resolve(
        style,
        colors,
        root: entry.key == 'root',
        branch: entry.key.startsWith('b') ? 1 : 0,
      );
      paint.color = tokens.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(entry.value, Radius.circular(tokens.radius)),
        paint,
      );
      paint
        ..color = tokens.border
        ..style = PaintingStyle.stroke;
      if (tokens.underline) {
        canvas.drawLine(entry.value.bottomLeft, entry.value.bottomRight, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(entry.value, Radius.circular(tokens.radius)),
          paint,
        );
      }
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  bool shouldRepaint(_MapMiniature old) =>
      old.layout != layout || old.colors != colors || old.style != style;
}

/// An anchored, non-modal panel: the document stays visible and interactive.
class WorkspacePickerAnchor extends StatelessWidget {
  const WorkspacePickerAnchor({
    super.key,
    required this.vm,
    required this.picker,
    required this.controller,
    required this.child,
    this.popupKey,
  });
  final WorkspaceViewModel vm;
  final WorkspacePicker picker;
  final MenuController controller;
  final Widget child;
  final GlobalKey? popupKey;

  @override
  Widget build(BuildContext context) {
    final width = math.min(
      picker == WorkspacePicker.typography ? 650.0 : 496.0,
      vm.guiding &&
              vm.windowSize.shortestSide < 600 &&
              vm.windowSize.width > vm.windowSize.height
          ? vm.windowSize.width / 2 - 24
          : vm.windowSize.width - 24,
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
                  key: popupKey,
                  constraints: BoxConstraints(
                    maxHeight: vm.guiding && vm.windowSize.width < 600
                        ? math.max(160, vm.windowSize.height * .4)
                        : math.max(160, vm.windowSize.height - 220),
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
                                    : picker == WorkspacePicker.map
                                    ? context.l10n.mapAppearance
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
                        if (picker == WorkspacePicker.layout)
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
                        else if (picker == WorkspacePicker.map)
                          MapAppearanceChoices(vm: vm, width: width - 32)
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

class MapAppearanceChoices extends StatefulWidget {
  const MapAppearanceChoices({
    super.key,
    required this.vm,
    required this.width,
  });
  final WorkspaceViewModel vm;
  final double width;
  @override
  State<MapAppearanceChoices> createState() => _MapAppearanceChoicesState();
}

class _MapAppearanceChoicesState extends State<MapAppearanceChoices> {
  bool _styles = false;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text(context.l10n.mapStructure)),
          ButtonSegment(value: true, label: Text(context.l10n.mapStyle)),
        ],
        selected: {_styles},
        onSelectionChanged: (value) => setState(() => _styles = value.single),
      ),
      const SizedBox(height: 14),
      if (!_styles)
        MindMapLayoutChoices(vm: widget.vm, width: widget.width)
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final style in MindMapStyle.values)
              _ChoiceCard(
                key: ValueKey('map-style-${style.name}'),
                width: (widget.width - 8) / 2,
                height: 100,
                selected: widget.vm.map.style == style,
                label: context.l10n.mapStyleName(style),
                onTap: () => widget.vm.setMapStyle(style),
                child: Column(
                  children: [
                    Expanded(
                      child: SizedBox.expand(
                        child: CustomPaint(
                          painter: _MapMiniature(
                            MindMapLayout.compute(
                              MindMapLayoutChoices._sample,
                              mode: widget.vm.map.mode,
                            ),
                            Theme.of(context).colorScheme,
                            style,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.mapStyleName(style),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
    ],
  );
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
    final colors = Theme.of(context).colorScheme;
    final choices = [
      for (final type in MarkdownTypography.values)
        ListTile(
          key: ValueKey('typography-${type.name}'),
          minTileHeight: 36,
          dense: true,
          selected: vm.typography == type,
          selectedTileColor: colors.primaryContainer,
          selectedColor: colors.onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: Text(context.l10n.typographyName(type)),
          trailing: vm.typography == type ? const AppGlyph('check') : null,
          onTap: () => vm.updateAppearance(typography: type),
        ),
    ];
    final preview = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Theme(
        data: documentTheme(Theme.of(context)),
        child: SingleChildScrollView(
          key: const PageStorageKey('typography-article-preview'),
          primary: false,
          padding: const EdgeInsets.all(24),
          child: MarkdownReader(
            data: context.l10n.typographyPreviewMarkdown,
            typography: vm.typography,
            compact: vm.compact,
            fontSize: 15,
            selectable: false,
          ),
        ),
      ),
    );
    if (width < 500) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final type in MarkdownTypography.values)
                ChoiceChip(
                  key: ValueKey('typography-${type.name}'),
                  label: Text(context.l10n.typographyName(type)),
                  selected: vm.typography == type,
                  onSelected: (_) => vm.updateAppearance(typography: type),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 300, child: preview),
        ],
      );
    }
    return SizedBox(
      height: (MediaQuery.sizeOf(context).height - 390).clamp(210.0, 440.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 148,
            child: SingleChildScrollView(
              primary: false,
              child: Column(children: choices),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: preview),
        ],
      ),
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
