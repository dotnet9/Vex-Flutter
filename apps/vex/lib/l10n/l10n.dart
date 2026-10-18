import 'package:flutter/widgets.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

import '../domain/workspace.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Stable preference keys; display each language in its own writing system.
const languageNames = {
  'zh': '简体中文',
  'zh_Hant': '繁體中文',
  'en': 'English',
  'ja': '日本語',
};

String languageForLocale(Locale locale) => switch (locale.languageCode) {
  'zh' =>
    locale.scriptCode == 'Hant' ||
            (locale.scriptCode != 'Hans' &&
                const ['TW', 'HK', 'MO'].contains(locale.countryCode))
        ? 'zh_Hant'
        : 'zh',
  'ja' => 'ja',
  _ => 'en',
};

String languageForLocales(List<Locale> locales) => languageForLocale(
  locales.firstWhere(
    (locale) => const ['zh', 'en', 'ja'].contains(locale.languageCode),
    orElse: () => const Locale('en'),
  ),
);

Locale localeForLanguage(String language) => language == 'zh_Hant'
    ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
    : Locale(languageNames.containsKey(language) ? language : 'en');

AppLocalizations stringsForLanguage(String language) =>
    lookupAppLocalizations(localeForLanguage(language));

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension LocalizedChoices on AppLocalizations {
  String mapStyleName(MindMapStyle style) => switch (style) {
    MindMapStyle.quiet => mapQuiet,
    MindMapStyle.colorful => mapColorful,
    MindMapStyle.outline => mapOutline,
    MindMapStyle.capsule => mapCapsule,
    MindMapStyle.underline => mapUnderline,
    MindMapStyle.mono => mapMono,
  };
  String tableCommandName(MarkdownTableCommand command) => switch (command) {
    MarkdownTableCommand.rowAbove => tableRowAbove,
    MarkdownTableCommand.rowBelow => tableRowBelow,
    MarkdownTableCommand.columnBefore => tableColumnBefore,
    MarkdownTableCommand.columnAfter => tableColumnAfter,
    MarkdownTableCommand.rowUp => tableRowUp,
    MarkdownTableCommand.rowDown => tableRowDown,
    MarkdownTableCommand.columnLeft => tableColumnLeft,
    MarkdownTableCommand.columnRight => tableColumnRight,
    MarkdownTableCommand.alignLeft => tableAlignLeft,
    MarkdownTableCommand.alignCenter => tableAlignCenter,
    MarkdownTableCommand.alignRight => tableAlignRight,
    MarkdownTableCommand.deleteRow => tableDeleteRow,
    MarkdownTableCommand.deleteColumn => tableDeleteColumn,
    MarkdownTableCommand.copy => tableCopy,
    MarkdownTableCommand.format => tableFormat,
    MarkdownTableCommand.delete => tableDelete,
  };
  String mapLayoutName(MindMapLayoutMode mode) => switch (mode) {
    MindMapLayoutMode.right => mapLayoutRight,
    MindMapLayoutMode.balanced => mapLayoutBalanced,
    MindMapLayoutMode.radial => mapLayoutRadial,
    MindMapLayoutMode.down => mapLayoutDown,
    MindMapLayoutMode.outline => mapLayoutOutline,
    MindMapLayoutMode.fishbone => mapLayoutFishbone,
  };
  String layoutName(WorkspaceLayout layout) => switch (layout) {
    WorkspaceLayout.instant => instantEditing,
    WorkspaceLayout.source => source,
    WorkspaceLayout.read => read,
    WorkspaceLayout.map => map,
    WorkspaceLayout.sourceRender => layoutSourceRender,
    WorkspaceLayout.sourceMap => layoutSourceMap,
    WorkspaceLayout.instantMap => layoutInstantMap,
    WorkspaceLayout.three => layoutThree,
  };

  String typographyName(MarkdownTypography type) => switch (type) {
    MarkdownTypography.simple => typeSimple,
    MarkdownTypography.document => typeDocument,
    MarkdownTypography.book => typeBook,
    MarkdownTypography.technical => typeTechnical,
    MarkdownTypography.column => typeColumn,
    MarkdownTypography.editorial => typeEditorial,
    MarkdownTypography.academic => typeAcademic,
    MarkdownTypography.journal => typeJournal,
    MarkdownTypography.handbook => typeHandbook,
  };

  String typographyDescription(MarkdownTypography type) => switch (type) {
    MarkdownTypography.simple => typeSimpleNote,
    MarkdownTypography.document => typeDocumentNote,
    MarkdownTypography.book => typeBookNote,
    MarkdownTypography.technical => typeTechnicalNote,
    MarkdownTypography.column => typeColumnNote,
    MarkdownTypography.editorial => typeEditorialNote,
    MarkdownTypography.academic => typeAcademicNote,
    MarkdownTypography.journal => typeJournalNote,
    MarkdownTypography.handbook => typeHandbookNote,
  };

  String paletteName(String palette) => switch (palette) {
    'graphite' => paletteGraphite,
    'ocean' => paletteOcean,
    'sand' => paletteSand,
    'rose' => paletteRose,
    'iris' => paletteIris,
    'olive' => paletteOlive,
    'ember' => paletteEmber,
    _ => paletteWeft,
  };

  MarkdownEditorLabels get editorLabels => MarkdownEditorLabels(
    codeLanguage: codeLanguage,
    placeholder: writingPlaceholder,
    newParagraph: newParagraph,
    diagramSource: mermaidSource,
    diagramPreview: mermaidPreview,
    diagramUnavailable: mermaidUnavailable,
    diagramError: mermaidError,
  );

  MindMapLabels get mapLabels => MindMapLabels(
    zoomOut: zoomOut,
    zoomIn: zoomIn,
    fitCanvas: fitCanvas,
    expand: expand,
    collapse: collapse,
  );

  Map<String, String> get sampleDocuments => {
    sampleDesignName: sampleDesign,
    sampleWeeklyName: sampleWeekly,
    sampleReadingName: sampleReading,
    sampleStartName: sampleStart,
    sampleExportName: sampleExport,
  };
}
