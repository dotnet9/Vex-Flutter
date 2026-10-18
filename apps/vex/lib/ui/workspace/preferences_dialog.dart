import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:vex_editor/vex_editor.dart';

import '../../domain/export_preferences.dart';
import '../../domain/file_preferences.dart';
import '../../domain/image_preferences.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import '../core/palette_tokens.dart';
import 'document_watermark.dart';
import 'mcp_settings_dialog.dart';
import 'preference_controls.dart';
import 'workspace_view_model.dart';

enum PreferenceCategory {
  general,
  editor,
  markdown,
  images,
  appearance,
  export,
  mcp,
}

Future<void> showPreferences(
  BuildContext context,
  WorkspaceViewModel vm, {
  PreferenceCategory? category,
  int mcpTab = 0,
}) => showDialog<void>(
  context: context,
  builder: (context) => LayoutBuilder(
    builder: (context, constraints) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: constraints.biggest),
      child: PreferencesDialog(
        vm: vm,
        initialCategory: category,
        mcpTab: mcpTab,
      ),
    ),
  ),
);

class PreferencesDialog extends StatefulWidget {
  const PreferencesDialog({
    super.key,
    required this.vm,
    this.initialCategory,
    this.mcpTab = 0,
  });
  final WorkspaceViewModel vm;
  final PreferenceCategory? initialCategory;
  final int mcpTab;
  @override
  State<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<PreferencesDialog> {
  late PreferenceCategory _category =
      widget.initialCategory ?? PreferenceCategory.general;
  late bool _detail = widget.initialCategory != null;
  late String _imageFolder = widget.vm.imagePreferences.folder;
  late String _exportFolder = widget.vm.exportPreferences.folder;
  String? _imageError, _exportError;
  final _scroll = ScrollController();
  WorkspaceViewModel get vm => widget.vm;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  (String, String) _label(PreferenceCategory category, AppLocalizations l) =>
      switch (category) {
        PreferenceCategory.general => (l.prefGeneral, 'file'),
        PreferenceCategory.editor => (l.editor, 'edit'),
        PreferenceCategory.markdown => ('Markdown', 'code'),
        PreferenceCategory.images => (l.prefImages, 'image'),
        PreferenceCategory.appearance => (l.appearance, 'palette'),
        PreferenceCategory.export => (l.prefExport, 'export'),
        PreferenceCategory.mcp => ('MCP', 'terminal'),
      };

  void _select(PreferenceCategory category) {
    FocusScope.of(context).unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _category = category;
      _detail = true;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final l = context.l10n, c = Theme.of(context).colorScheme;
      final small = preferenceCompact(context);
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180);
      final navigation = ListView(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 16 : 10,
          vertical: small ? 8 : 18,
        ),
        children: [
          for (final category in PreferenceCategory.values)
            Padding(
              padding: EdgeInsets.only(bottom: small ? 0 : 3),
              child: Semantics(
                selected: _category == category,
                child: Material(
                  color: !small && _category == category
                      ? c.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(small ? 0 : 5),
                  child: InkWell(
                    key: ValueKey('preference-category-${category.name}'),
                    borderRadius: BorderRadius.circular(small ? 0 : 5),
                    onTap: () => _select(category),
                    child: Container(
                      constraints: BoxConstraints(minHeight: small ? 56 : 40),
                      padding: EdgeInsets.symmetric(
                        horizontal: small ? 8 : 12,
                        vertical: 9,
                      ),
                      decoration: small
                          ? BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: c.outlineVariant),
                              ),
                            )
                          : null,
                      child: Row(
                        children: [
                          AppGlyph(
                            _label(category, l).$2,
                            size: 17,
                            color: !small && _category == category
                                ? c.primary
                                : c.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _label(category, l).$1,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: !small && _category == category
                                    ? c.primary
                                    : c.onSurface,
                                fontWeight: !small && _category == category
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (small) const AppGlyph('chevron-right', size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
      final content = Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          key: const ValueKey('preferences-scroll'),
          controller: _scroll,
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: small ? 20 : 22,
          ),
          child: AnimatedSwitcher(
            duration: duration,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .015), end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_category),
              child: _content(context),
            ),
          ),
        ),
      );
      return Dialog(
        insetPadding: small ? EdgeInsets.zero : const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(small ? 0 : 8),
          side: small ? BorderSide.none : BorderSide(color: c.outlineVariant),
        ),
        child: SizedBox(
          key: const ValueKey('preferences-dialog'),
          width: small ? double.infinity : 675,
          height: small
              ? double.infinity
              : math.min(700, MediaQuery.sizeOf(context).height - 48),
          child: SafeArea(
            top: small,
            bottom: small,
            child: Column(
              children: [
                Container(
                  key: const ValueKey('preferences-header'),
                  height: small ? 52 : 36,
                  padding: EdgeInsets.only(left: small && _detail ? 8 : 16),
                  child: Row(
                    children: [
                      if (small && _detail)
                        AppButton(
                          icon: 'arrow-left',
                          tooltip: l.prefBack,
                          height: 44,
                          onPressed: () => setState(() => _detail = false),
                        ),
                      Expanded(
                        child: Text(
                          small && _detail
                              ? _label(_category, l).$1
                              : l.settings,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (small)
                        AppButton(
                          icon: 'x',
                          tooltip: l.close,
                          height: 44,
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        AppCloseButton(onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: small
                      ? AnimatedSwitcher(
                          duration: duration,
                          layoutBuilder: (current, previous) => Stack(
                            fit: StackFit.expand,
                            children: [...previous, ?current],
                          ),
                          child: _detail
                              ? KeyedSubtree(
                                  key: const ValueKey('detail'),
                                  child: content,
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('categories'),
                                  child: navigation,
                                ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 148,
                              decoration: BoxDecoration(
                                color: c.surface,
                                border: Border(
                                  right: BorderSide(color: c.outlineVariant),
                                ),
                              ),
                              child: navigation,
                            ),
                            Expanded(child: content),
                          ],
                        ),
                ),
                const Divider(height: 1),
                Container(
                  key: const ValueKey('preferences-footer'),
                  height: small ? 64 : 53,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          vm.preferencesError != null
                              ? l.preferencesSaveFailed(vm.preferencesError!)
                              : vm.preferencesSaving
                              ? l.prefSaving
                              : l.prefSaved,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                      AppButton(
                        label: l.done,
                        bordered: true,
                        height: small ? 44 : 32,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _content(BuildContext context) {
    final l = context.l10n, f = vm.filePreferences, e = vm.editingPreferences;
    final ex = vm.exportPreferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: switch (_category) {
        PreferenceCategory.general => [
          PreferenceDropdown(
            key: const ValueKey('language-setting'),
            label: l.language,
            value: vm.language,
            items: languageNames.entries.map((e) => (e.key, e.value)).toList(),
            onChanged: (v) => vm.updateAppearance(language: v),
          ),
          PreferenceDropdown(
            label: l.prefStartup,
            value: f.restoreWorkspace,
            items: [(false, l.prefEmpty), (true, l.prefRestore)],
            onChanged: (v) => vm.updateFilePreferences(restoreWorkspace: v),
          ),
          PreferenceSection(l.prefSaveRecovery),
          PreferenceSwitch(
            label: l.prefAutoSave,
            value: f.autoSave,
            onChanged: (v) => vm.updateFilePreferences(autoSave: v),
          ),
          PreferenceDropdown(
            label: l.prefSaveDelay,
            value: f.saveDelay,
            items: [
              for (final seconds in [2, 5, 10])
                (seconds, l.prefSeconds(seconds)),
            ],
            onChanged: (v) => vm.updateFilePreferences(saveDelay: v),
          ),
          PreferenceSwitch(
            label: l.prefRecovery,
            value: f.recovery,
            onChanged: (v) => vm.updateFilePreferences(recovery: v),
          ),
          PreferenceSection(l.prefNewDefaults),
          PreferenceDropdown(
            label: l.prefEncoding,
            value: f.newDocumentFormat.encoding,
            items: const [
              (DocumentEncoding.utf8, 'UTF-8'),
              (DocumentEncoding.utf8Bom, 'UTF-8 BOM'),
              (DocumentEncoding.gb18030, 'GB18030'),
            ],
            onChanged: (v) => vm.updateFilePreferences(encoding: v),
          ),
          PreferenceDropdown(
            label: l.prefNewline,
            value: f.newDocumentFormat.newline,
            items: [
              (DocumentNewline.system, l.followSystem),
              (DocumentNewline.lf, 'LF'),
              (DocumentNewline.crlf, 'CRLF'),
            ],
            onChanged: (v) => vm.updateFilePreferences(newline: v),
          ),
        ],
        PreferenceCategory.editor => [
          PreferenceDropdown(
            label: l.prefFont,
            value: e.font,
            items: [
              (MarkdownBodyFont.system, l.prefSystemFont),
              (MarkdownBodyFont.serif, l.prefSerifFont),
              (MarkdownBodyFont.mono, l.prefMonoFont),
            ],
            onChanged: (v) => vm.updateEditorPreferences(font: v),
          ),
          PreferenceSlider(
            label: l.prefBodySize,
            value: vm.fontSize,
            min: 12,
            max: 24,
            divisions: 12,
            output: '${vm.fontSize.round()} px',
            onChanged: (v) => vm.updateAppearance(fontSize: v),
          ),
          PreferenceSlider(
            label: l.prefCodeSize,
            value: e.codeSize,
            min: 11,
            max: 20,
            divisions: 9,
            output: '${e.codeSize.round()} px',
            onChanged: (v) => vm.updateEditorPreferences(codeSize: v),
          ),
          PreferenceDropdown(
            label: l.prefIndent,
            value: e.indent,
            items: [
              for (final count in [2, 4, 8]) (count, l.prefSpaces(count)),
            ],
            onChanged: (v) => vm.updateEditorPreferences(indent: v),
          ),
          PreferenceSwitch(
            label: l.prefAutoPair,
            value: e.autoPair,
            onChanged: (v) => vm.updateEditorPreferences(autoPair: v),
          ),
          PreferenceSection(l.prefCodeSource),
          PreferenceSwitch(
            label: l.prefCodeWrap,
            value: e.codeWrap,
            onChanged: (v) => vm.updateEditorPreferences(codeWrap: v),
          ),
          PreferenceSwitch(
            label: l.sourceLineNumbers,
            value: vm.lineNumbers,
            onChanged: (v) => vm.updateAppearance(lineNumbers: v),
          ),
          PreferenceSection(l.prefWriting),
          PreferenceSwitch(
            label: l.focusMode,
            value: vm.focusMode,
            onChanged: (_) => vm.toggleFocus(),
          ),
          PreferenceSwitch(
            label: l.typewriterMode,
            value: vm.typewriter,
            onChanged: (_) => vm.toggleTypewriter(),
          ),
        ],
        PreferenceCategory.markdown => [
          PreferenceSwitch(
            label: l.prefMath,
            value: vm.markdownPreferences.math,
            onChanged: (v) => vm.updateMarkdownPreferences(
              vm.markdownPreferences.copyWith(math: v),
            ),
          ),
          PreferenceSwitch(
            label: l.prefChemistry,
            value: vm.markdownPreferences.chemistry,
            onChanged: (v) => vm.updateMarkdownPreferences(
              vm.markdownPreferences.copyWith(chemistry: v),
            ),
          ),
          PreferenceSwitch(
            label: l.mermaidDiagrams,
            value: vm.markdownPreferences.mermaid,
            onChanged: (v) => vm.updateMarkdownPreferences(
              vm.markdownPreferences.copyWith(mermaid: v),
            ),
          ),
          PreferenceSection(l.prefInlineSyntax),
          PreferenceSwitch(
            label: l.prefSubscript,
            value: vm.markdownPreferences.subscript,
            onChanged: (v) => vm.updateMarkdownPreferences(
              vm.markdownPreferences.copyWith(subscript: v),
            ),
          ),
          PreferenceSwitch(
            label: l.prefHighlight,
            value: vm.markdownPreferences.highlight,
            onChanged: (v) => vm.updateMarkdownPreferences(
              vm.markdownPreferences.copyWith(highlight: v),
            ),
          ),
          PreferenceSwitch(
            label: l.prefAutoLink,
            value: vm.markdownPreferences.autoLink,
            onChanged: (v) => vm.updateMarkdownPreferences(
              vm.markdownPreferences.copyWith(autoLink: v),
            ),
          ),
          PreferenceSwitch(
            label: l.prefSoftBreak,
            value: vm.markdownPreferences.softBreak,
            onChanged: (v) => vm.updateMarkdownPreferences(
              vm.markdownPreferences.copyWith(softBreak: v),
            ),
          ),
        ],
        PreferenceCategory.images => [
          PreferenceSwitch(
            label: l.prefImageCopy,
            value: vm.imagePreferences.copy,
            onChanged: (v) => vm.updateImagePreferences(copy: v),
          ),
          PreferenceSwitch(
            label: l.prefImageRelative,
            value: vm.imagePreferences.relative,
            onChanged: (v) => vm.updateImagePreferences(relative: v),
          ),
          PreferenceText(
            label: l.prefAssetFolder,
            value: _imageFolder,
            error: _imageError,
            onChanged: (v) {
              setState(() {
                _imageFolder = v;
                _imageError = ImagePreferences.validFolder(v)
                    ? null
                    : l.prefFolderError;
              });
              if (_imageError == null) vm.updateImagePreferences(folder: v);
            },
          ),
        ],
        PreferenceCategory.appearance => [
          PreferenceDropdown(
            label: l.themeMode,
            value: vm.themeMode,
            items: [
              (ThemeMode.system, l.followSystem),
              (ThemeMode.light, l.light),
              (ThemeMode.dark, l.dark),
            ],
            onChanged: (v) => vm.updateAppearance(mode: v),
          ),
          PreferenceRow(
            label: l.interfaceColors,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final key in paletteNames.keys)
                  Tooltip(
                    message: l.paletteName(key),
                    child: Semantics(
                      label: l.paletteName(key),
                      selected: vm.palette == key,
                      button: true,
                      child: InkWell(
                        onTap: () => vm.updateAppearance(palette: key),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: paletteSchemes['$key-light']!.primary,
                            border: Border.all(
                              color: vm.palette == key
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PreferenceDropdown(
            label: l.bodyTypography,
            value: vm.typography,
            items: [
              for (final type in MarkdownTypography.values)
                (type, l.typographyName(type)),
            ],
            onChanged: (v) => vm.updateAppearance(typography: v),
          ),
          PreferenceSwitch(
            label: l.compactSpacing,
            value: vm.compact,
            onChanged: (v) => vm.updateAppearance(compact: v),
          ),
          PreferenceDropdown(
            label: l.prefZoom,
            value: vm.contentZoom,
            items: const [
              (.9, '90%'),
              (1.0, '100%'),
              (1.1, '110%'),
              (1.25, '125%'),
            ],
            onChanged: (v) => vm.updateAppearance(contentZoom: v),
          ),
          PreferenceSwitch(
            label: l.prefStatusbar,
            value: vm.statusbar,
            onChanged: (v) => vm.updateAppearance(statusbar: v),
          ),
          PreferenceSwitch(
            label: l.prefMotion,
            value: vm.motion,
            onChanged: (v) => vm.updateAppearance(motion: v),
          ),
          PreferenceSection(l.documentWatermark),
          PreferenceSwitch(
            label: l.watermarkPreview,
            value: vm.watermark.preview,
            onChanged: (v) => vm.updateWatermark(preview: v),
          ),
          PreferenceSwitch(
            label: l.watermarkExport,
            value: vm.watermark.export,
            onChanged: (v) => vm.updateWatermark(export: v),
          ),
          PreferenceText(
            key: const ValueKey('watermark-text'),
            label: l.watermarkText,
            value: vm.watermark.text,
            maxLength: 60,
            onChanged: (v) => vm.updateWatermark(text: v),
          ),
          PreferenceSlider(
            label: l.watermarkOpacity,
            value: vm.watermark.opacity,
            min: 0,
            max: .5,
            divisions: 50,
            output: '${(vm.watermark.opacity * 100).round()}%',
            onChanged: (v) => vm.updateWatermark(opacity: v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: ClipRect(
              child: DocumentWatermark(
                preferences: vm.watermark.copyWith(preview: true),
                child: Center(
                  child: Text(l.slogan, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ),
        ],
        PreferenceCategory.export => [
          PreferenceDropdown(
            label: l.prefDefaultFormat,
            value: ex.format,
            items: [
              ('html', 'HTML'),
              ('pdf', 'PDF'),
              ('md', 'Markdown'),
              ('docx', 'Word'),
              ('png', l.mindMapPng),
            ],
            onChanged: (v) => vm.updateExportPreferences(format: v),
          ),
          PreferenceText(
            label: l.prefDefaultDirectory,
            value: _exportFolder,
            hint: l.prefDocumentDirectory,
            error: _exportError,
            suffix: AppButton(
              icon: 'folder',
              tooltip: l.openFolder,
              height: 28,
              padding: 5,
              onPressed: () async {
                final directory = await FilePicker.getDirectoryPath();
                if (mounted && directory != null) {
                  setState(() {
                    _exportFolder = directory;
                    _exportError = null;
                  });
                  vm.updateExportPreferences(folder: directory);
                }
              },
            ),
            onChanged: (v) {
              setState(() {
                _exportFolder = v;
                _exportError = v.trim().isEmpty || p.isAbsolute(v.trim())
                    ? null
                    : l.prefMcpDirectoryError;
              });
              if (_exportError == null) {
                vm.updateExportPreferences(folder: v.trim());
              }
            },
          ),
          PreferenceSwitch(
            label: l.prefOpenAfterExport,
            value: ex.openAfterExport,
            onChanged: (v) => vm.updateExportPreferences(openAfterExport: v),
          ),
          PreferenceSection(l.documentWatermark),
          PreferenceSwitch(
            label: l.watermarkExport,
            value: vm.watermark.export,
            onChanged: (v) => vm.updateWatermark(export: v),
          ),
          AppButton(
            label: l.watermarkText,
            icon: 'edit',
            onPressed: () => _select(PreferenceCategory.appearance),
          ),
          const PreferenceSection('PDF'),
          PreferenceDropdown(
            label: l.prefPaper,
            value: ex.paper,
            items: const [
              (ExportPaper.a4, 'A4'),
              (ExportPaper.letter, 'Letter'),
              (ExportPaper.a5, 'A5'),
            ],
            onChanged: (v) => vm.updateExportPreferences(paper: v),
          ),
          PreferenceSlider(
            label: l.prefMargin,
            value: ex.margin,
            min: 10,
            max: 30,
            divisions: 20,
            output: '${ex.margin.round()} mm',
            onChanged: (v) => vm.updateExportPreferences(margin: v),
          ),
          const PreferenceSection('HTML'),
          PreferenceSwitch(
            label: l.prefHtmlStyle,
            value: ex.htmlStyle,
            onChanged: (v) => vm.updateExportPreferences(htmlStyle: v),
          ),
        ],
        PreferenceCategory.mcp => [
          McpSettingsPane(mcp: vm.mcp, initialTab: widget.mcpTab),
        ],
      },
    );
  }
}
