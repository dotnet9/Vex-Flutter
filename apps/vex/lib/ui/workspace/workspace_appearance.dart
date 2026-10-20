import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../core/palette_tokens.dart';
import 'workspace_view_model.dart';

class WorkspaceAppearanceAnchor extends StatelessWidget {
  const WorkspaceAppearanceAnchor({
    super.key,
    required this.vm,
    required this.controller,
    required this.child,
  });
  final WorkspaceViewModel vm;
  final MenuController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: controller,
    consumeOutsideTap: false,
    alignmentOffset: const Offset(0, 6),
    style: const MenuStyle(
      alignment: AlignmentDirectional.bottomEnd,
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
    ),
    menuChildren: [
      ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final l = context.l10n;
          final width = math.min(340.0, MediaQuery.sizeOf(context).width - 24);
          return SizedBox(
            key: const ValueKey('appearance-picker'),
            width: width,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height - 100,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.themeMode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<ThemeMode>(
                      groupValue: vm.themeMode,
                      onChanged: (value) => vm.updateAppearance(mode: value),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final (mode, label) in [
                            (ThemeMode.light, l.light),
                            (ThemeMode.dark, l.dark),
                            (ThemeMode.system, l.followSystem),
                          ])
                            MergeSemantics(
                              child: InkWell(
                                canRequestFocus: false,
                                borderRadius: BorderRadius.circular(5),
                                onTap: () => vm.updateAppearance(mode: mode),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 28,
                                        child: Radio<ThemeMode>(
                                          key: ValueKey(
                                            'appearance-mode-${mode.name}',
                                          ),
                                          value: mode,
                                          autofocus: vm.themeMode == mode,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        label,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l.interfaceColors,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final palette in paletteNames.keys)
                          SizedBox(
                            width: (width - 40) / 2,
                            child: Semantics(
                              selected: vm.palette == palette,
                              child: TextButton(
                                key: ValueKey('appearance-palette-$palette'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  backgroundColor: vm.palette == palette
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: .08)
                                      : null,
                                ),
                                onPressed: () =>
                                    vm.updateAppearance(palette: palette),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: paletteSchemes['$palette-light']!
                                            .primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l.paletteName(palette),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ],
    child: child,
  );
}
