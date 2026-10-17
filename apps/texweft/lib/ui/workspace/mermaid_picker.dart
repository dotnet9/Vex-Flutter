import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:texweft_editor/texweft_editor.dart';

import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';

Future<MermaidTemplate?> showMermaidPicker(BuildContext context) =>
    showDialog<MermaidTemplate>(
      context: context,
      builder: (context) {
        final l = context.l10n, c = Theme.of(context).colorScheme;
        final chinese = l.localeName.startsWith('zh');
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 420,
            height: math.min(660, MediaQuery.sizeOf(context).height - 40),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l.mermaidDiagrams,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AppCloseButton(onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (var group = 0; group < 4; group++) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                          child: Text(
                            MermaidTemplate.groupLabel(group, chinese),
                            style: TextStyle(
                              fontSize: 12,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (final template in MermaidTemplate.values.where(
                          (t) => t.group == group,
                        ))
                          ListTile(
                            key: ValueKey('mermaid-template-${template.name}'),
                            dense: true,
                            minTileHeight: 44,
                            leading: const AppGlyph('map'),
                            title: Text(
                              template.label(chinese),
                              style: const TextStyle(fontSize: 14),
                            ),
                            onTap: () => Navigator.pop(context, template),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
