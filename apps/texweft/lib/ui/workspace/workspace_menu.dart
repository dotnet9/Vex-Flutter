import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:texweft_editor/texweft_editor.dart';

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/palette_tokens.dart';
import 'workspace_view_model.dart';

/// Shared command tree for desktop flyouts, native macOS menus and touch sheets.
final class WorkspaceMenuEntry {
  const WorkspaceMenuEntry(
    this.id,
    this.label, {
    this.children = const [],
    this.shortcut,
    this.checked,
    this.enabled = true,
    this.icon,
  });
  const WorkspaceMenuEntry.separator()
    : id = '-',
      label = '',
      children = const [],
      shortcut = null,
      checked = null,
      enabled = false,
      icon = null;
  final String id, label;
  final String? icon;
  final List<WorkspaceMenuEntry> children;
  final SingleActivator? shortcut;
  final bool? checked;
  final bool enabled;
  bool get isSeparator => id == '-';
}

String workspaceMenuLabel(String label) =>
    label.replaceFirst(RegExp(r'\([A-Z]\)$'), '');

String workspaceShortcutLabel(SingleActivator? shortcut) {
  if (shortcut == null) return '';
  return [
    if (shortcut.meta) '⌘',
    if (shortcut.control) 'Ctrl',
    if (shortcut.alt) 'Alt',
    if (shortcut.shift) 'Shift',
    shortcut.trigger.keyLabel,
  ].join('+');
}

List<WorkspaceMenuEntry> workspaceMenus(
  WorkspaceViewModel vm, {
  required bool macOS,
  required bool desktop,
  required int maxPanes,
}) {
  final l = vm.strings;
  const divider = WorkspaceMenuEntry.separator();
  SingleActivator key(
    LogicalKeyboardKey trigger, {
    bool shift = false,
    bool primary = true,
  }) => SingleActivator(
    trigger,
    shift: shift,
    control: primary && !macOS,
    meta: primary && macOS,
  );
  WorkspaceMenuEntry item(
    String id,
    String label, {
    SingleActivator? shortcut,
    bool? checked,
    bool enabled = true,
  }) => WorkspaceMenuEntry(
    id,
    label,
    shortcut: shortcut,
    checked: checked,
    enabled: enabled,
  );
  WorkspaceMenuEntry group(
    String id,
    String label,
    List<WorkspaceMenuEntry> children, {
    String? icon,
  }) => WorkspaceMenuEntry(id, label, children: children, icon: icon);
  String title(String label) =>
      desktop && !macOS ? label : workspaceMenuLabel(label);
  String named(String label, String mnemonic) => title('$label($mnemonic)');
  final menus = <WorkspaceMenuEntry>[
    group('file', title(l.menuFile), [
      item('new', l.newDocument, shortcut: key(LogicalKeyboardKey.keyN)),
      divider,
      item('open', l.open, shortcut: key(LogicalKeyboardKey.keyO)),
      if (desktop) item('folder', l.openFolder),
      group('recent', l.openRecent, [
        if (vm.recent.isEmpty) item('no-recent', l.noRecent, enabled: false),
        for (final path in vm.recent) item('open-path:$path', path),
        if (vm.recent.isNotEmpty) ...[
          divider,
          item('clear-recent', l.clearRecent),
        ],
      ]),
      divider,
      item('save', l.save, shortcut: key(LogicalKeyboardKey.keyS)),
      item(
        'save-as',
        l.saveAs,
        shortcut: key(LogicalKeyboardKey.keyS, shift: true),
      ),
      item('save-all', l.saveAllDocuments),
      group('export', l.exportShareMenu, [
        item('export:html', 'HTML'),
        item('export:pdf', 'PDF'),
        item('export:docx', 'Word (.docx)'),
        item('export:png', l.mindMapPng),
      ]),
      if (desktop)
        item(
          'export:print',
          l.printPreview,
          shortcut: key(LogicalKeyboardKey.keyP, shift: true),
        ),
      divider,
      item(
        'close-document',
        l.closeDocument,
        shortcut: key(LogicalKeyboardKey.keyW),
      ),
      if (desktop && !macOS) item('exit', l.exit),
    ], icon: 'file'),
    group('edit', title(l.menuEdit), [
      item(
        'undo',
        l.undo,
        shortcut: key(LogicalKeyboardKey.keyZ),
        enabled: vm.editor.session.canUndo,
      ),
      item(
        'redo',
        l.redo,
        shortcut: key(
          macOS ? LogicalKeyboardKey.keyZ : LogicalKeyboardKey.keyY,
          shift: macOS,
        ),
        enabled: vm.editor.session.canRedo,
      ),
      divider,
      item(
        'cut',
        l.cut,
        shortcut: key(LogicalKeyboardKey.keyX),
        enabled:
            vm.editor.selection.isValid && !vm.editor.selection.isCollapsed,
      ),
      item('copy', l.copy, shortcut: key(LogicalKeyboardKey.keyC)),
      item('paste', l.paste, shortcut: key(LogicalKeyboardKey.keyV)),
      item('select-all', l.selectAll, shortcut: key(LogicalKeyboardKey.keyA)),
      divider,
      item('find', l.find, shortcut: key(LogicalKeyboardKey.keyF)),
      item(
        'replace',
        l.replace,
        shortcut: key(
          macOS ? LogicalKeyboardKey.keyF : LogicalKeyboardKey.keyH,
          shift: macOS,
        ),
      ),
    ], icon: 'edit'),
    group('paragraph', named(l.menuParagraph, 'P'), [
      item('format:paragraph', l.menuParagraph),
      for (var level = 1; level <= 6; level++)
        item('format:heading-$level', '${l.heading} $level'),
      divider,
      item('format:list', l.unorderedList),
      item('format:ordered', l.orderedList),
      item('format:task', l.taskList),
      item('format:quote', l.quote),
      divider,
      group(
        'table',
        l.table,
        workspaceTableEntries(l, vm.editor.tableTarget()),
      ),
      item('format:code', l.codeBlock),
      item('format:math', l.mathBlock),
      item('format:rule', l.horizontalRule),
      group('mermaid', l.mermaidDiagrams, [
        for (var index = 0; index < 4; index++)
          group(
            'mermaid-group-$index',
            MermaidTemplate.groupLabel(index, vm.language.startsWith('zh')),
            [
              for (final template in MermaidTemplate.values.where(
                (t) => t.group == index,
              ))
                item(
                  'mermaid:${template.name}',
                  template.label(vm.language.startsWith('zh')),
                ),
            ],
          ),
      ]),
      item('format:footnote', l.footnote),
    ], icon: 'heading'),
    group('format', named(l.menuFormat, 'O'), [
      item('format:bold', l.bold, shortcut: key(LogicalKeyboardKey.keyB)),
      item('format:italic', l.italic, shortcut: key(LogicalKeyboardKey.keyI)),
      item('format:strike', l.strike),
      item('format:highlight', l.highlight),
      item('format:superscript', l.superscript),
      item('format:subscript', l.subscript),
      item('format:inline-code', l.inlineCode),
      divider,
      item('format:link', l.link, shortcut: key(LogicalKeyboardKey.keyK)),
      item('format:image', l.image),
      divider,
      item('format:clear', l.clearFormatting),
    ], icon: 'bold'),
    group('view', title(l.menuView), [
      group('layouts', l.workspaceLayoutMenu, [
        for (final layout in WorkspaceLayout.values.where(
          (layout) => layout.panes.length <= maxPanes,
        ))
          item(
            'layout:${layout.name}',
            l.layoutName(layout),
            checked: vm.layout == layout,
          ),
      ]),
      group('navigation', l.menuNavigation, [
        if (desktop) item('sidebar', l.toggleSidebar, checked: vm.sidebar),
        item('files', l.files),
        item('outline', l.outline),
      ]),
      group('display', l.menuDisplay, [
        item('lines', l.sourceLineNumbers, checked: vm.lineNumbers),
        item('watermark', l.watermarkPreview, checked: vm.watermark.preview),
        item('pairs', l.prefAutoPair, checked: vm.editingPreferences.autoPair),
        if (desktop) item('statusbar', l.prefStatusbar, checked: vm.statusbar),
      ]),
      group('writing', l.menuWriting, [
        item(
          'presentation',
          l.presentationMode,
          shortcut: key(LogicalKeyboardKey.f5, primary: false),
        ),
        item(
          'focus',
          l.focusMode,
          shortcut: key(LogicalKeyboardKey.f8, primary: false),
          checked: vm.focusMode,
        ),
        item('typewriter', l.typewriterMode, checked: vm.typewriter),
        item('motion', l.prefMotion, checked: vm.motion),
      ]),
      divider,
      group('appearance', l.appearanceMenu, [
        item(
          'theme:system',
          l.followSystem,
          checked: vm.themeMode == ThemeMode.system,
        ),
        item('theme:light', l.light, checked: vm.themeMode == ThemeMode.light),
        item('theme:dark', l.dark, checked: vm.themeMode == ThemeMode.dark),
        divider,
        for (final palette in paletteNames.keys)
          item(
            'palette:$palette',
            l.paletteName(palette),
            checked: vm.palette == palette,
          ),
      ]),
      group('typography', l.markdownTypography, [
        for (final type in MarkdownTypography.values)
          item(
            'typography:${type.name}',
            l.typographyName(type),
            checked: vm.typography == type,
          ),
        divider,
        item('compact', l.compactSpacing, checked: vm.compact),
      ]),
      if (desktop && !macOS)
        group('window', l.menuWindow, [
          item(
            'fullscreen',
            l.fullscreen,
            shortcut: key(LogicalKeyboardKey.f11, primary: false),
          ),
          item('maximize', l.maximizeRestore),
        ]),
      divider,
      item('zoom-in', l.zoomIn),
      item('zoom-out', l.zoomOut),
      item('zoom-reset', l.actualSize),
    ], icon: 'eye'),
    group('tools', title(l.menuTools), [
      if (!macOS) ...[
        item('settings', l.settings, shortcut: key(LogicalKeyboardKey.comma)),
        divider,
      ],
      item('summary', l.summarySettings),
      divider,
      item('mcp', l.mcpSettings),
      item('mcp-audit', l.mcpAudit),
    ], icon: 'gear'),
    group('help', title(l.menuHelp), [
      item('guide', l.quickStart),
      item('mermaid-examples', l.mermaidExamples),
      divider,
      item('changelog', l.changelog),
      item('thanks', l.builtinThanks),
      divider,
      item('website', l.officialWebsite),
      item('feedback', l.feedback),
      if (!macOS) item('about', l.about),
    ], icon: 'info'),
  ];
  return menus;
}

List<WorkspaceMenuEntry> workspaceTableEntries(
  AppLocalizations l,
  MarkdownTableTarget? target, {
  bool readOnly = false,
}) => [
  if (!readOnly) WorkspaceMenuEntry('format:table', l.insertTable),
  if (!readOnly) const WorkspaceMenuEntry.separator(),
  for (final command in MarkdownTableCommand.values) ...[
    if (const [
      MarkdownTableCommand.columnBefore,
      MarkdownTableCommand.rowUp,
      MarkdownTableCommand.alignLeft,
      MarkdownTableCommand.deleteRow,
      MarkdownTableCommand.copy,
      MarkdownTableCommand.delete,
    ].contains(command))
      const WorkspaceMenuEntry.separator(),
    WorkspaceMenuEntry(
      'table:${command.name}',
      l.tableCommandName(command),
      enabled:
          target?.can(command) == true &&
          (!readOnly || command == MarkdownTableCommand.copy),
      checked: switch (command) {
        MarkdownTableCommand.alignLeft =>
          target?.table.alignments[target.column] ==
              MarkdownTableAlignment.left,
        MarkdownTableCommand.alignCenter =>
          target?.table.alignments[target.column] ==
              MarkdownTableAlignment.center,
        MarkdownTableCommand.alignRight =>
          target?.table.alignments[target.column] ==
              MarkdownTableAlignment.right,
        _ => null,
      },
    ),
  ],
];

List<PlatformMenuItem> workspacePlatformItems(
  List<WorkspaceMenuEntry> entries,
  ValueChanged<String> onAction,
) {
  final groups = <PlatformMenuItem>[];
  var current = <PlatformMenuItem>[];
  void flush() {
    if (current.isEmpty) return;
    groups.add(PlatformMenuItemGroup(members: current));
    current = [];
  }

  for (final entry in entries) {
    if (entry.isSeparator) {
      flush();
      continue;
    }
    current.add(
      entry.children.isNotEmpty
          ? PlatformMenu(
              label: entry.label,
              menus: workspacePlatformItems(entry.children, onAction),
            )
          : PlatformMenuItem(
              label: '${entry.checked == true ? '✓ ' : ''}${entry.label}',
              shortcut: entry.shortcut,
              onSelected: entry.enabled ? () => onAction(entry.id) : null,
            ),
    );
  }
  flush();
  return groups;
}
