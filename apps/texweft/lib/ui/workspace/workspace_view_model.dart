import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:texweft_editor/texweft_editor.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';
import 'package:texweft_mindmap/texweft_mindmap.dart';

import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/file_service.dart';
import '../../data/services/document_codec.dart';
import '../../domain/file_preferences.dart';
import '../../domain/export_preferences.dart';
import '../../domain/image_preferences.dart';
import '../../data/services/image_asset_service.dart';
import '../../domain/presentation.dart';
import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/palette_tokens.dart';
import 'presentation_controller.dart';
import 'workspace_mcp.dart';

final class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel({
    required this.files,
    required this.settings,
    required this.recovery,
    ImageAssetService? imageAssets,
    String initialLanguage = 'zh',
  }) : imageAssets = imageAssets ?? ImageAssetService(),
       language = languageNames.containsKey(initialLanguage)
           ? initialLanguage
           : 'en' {
    _blank = WorkspaceDocument(
      id: 'empty-workspace',
      name: strings.untitledFile,
      text: '',
    );
    current = _blank;
    _blank.editor.addListener(_changed);
    _map = MindMapController(_tree());
    mcp = WorkspaceMcp(this);
  }

  late WorkspaceDocument _blank;
  late final WorkspaceMcp mcp;

  AppLocalizations get strings => stringsForLanguage(language);
  final DocumentFileService files;
  final SettingsRepository settings;
  final RecoveryRepository recovery;
  final ImageAssetService imageAssets;
  ImagePreferences imagePreferences = const ImagePreferences();
  final filePreferences = FilePreferences();
  ExportPreferences exportPreferences = const ExportPreferences();
  WatermarkPreferences watermark = const WatermarkPreferences();
  final documents = <WorkspaceDocument>[];
  final recent = <String>[];
  OpenedFolder? folder;
  late WorkspaceDocument current;
  late final MindMapController _map;
  MindMapController get map => _map;
  MarkdownEditorController get editor => current.editor;
  WorkspaceLayout _layout = WorkspaceLayout.instant;
  WorkspaceViewport viewport = WorkspaceViewport.desktop;
  WorkspaceLayout get layout => _layout.constrainedTo(viewport);
  set layout(WorkspaceLayout value) => _layout = value;
  MarkdownTypography typography = MarkdownTypography.simple;
  ThemeMode themeMode = ThemeMode.light;
  String palette = 'weft', language;
  bool sidebar = true, outline = false, compact = false, lineNumbers = true;
  bool findVisible = false, replaceVisible = false, focusMode = false;
  bool typewriter = false;
  MarkdownEditingPreferences editingPreferences =
      const MarkdownEditingPreferences();
  MarkdownPreferences markdownPreferences = const MarkdownPreferences();
  double contentZoom = 1;
  bool statusbar = true, motion = true;
  PresentationController? presenter;
  bool get presentation => presenter != null;
  bool paragraphs = true, lists = true, blocks = false;
  int summaryLength = 30;
  double sidebarWidth = 226, fontSize = 16;
  String filter = '', findQuery = '', replacement = '';
  String Function(AppLocalizations)? _statusMessage;
  String get status => _statusMessage?.call(strings) ?? '';
  bool matchCase = false, regex = false, wholeWord = false;
  int matchIndex = -1;
  List<SourceRange> matches = [];
  bool _invalidRegex = false;
  String? get findError => _invalidRegex ? strings.invalidRegex : null;
  String? selectedHeadingId;
  OpenedDocument? externalChange;
  bool ready = false, busy = false, _disposed = false, _checking = false;
  bool preferencesSaving = false;
  String? preferencesError;
  int _preferencesRevision = 0;
  Future<void>? _preferencesWrite;
  Timer? _recoveryTimer, _externalTimer;
  final _saveTimers = <WorkspaceDocument, Timer>{};
  final _saveQueues = <WorkspaceDocument, Future<bool>>{};
  final _headingForNode = <String, String>{};
  List<Map<String, Object?>> recoverable = [];

  Future<void> initialize({bool watchFiles = true}) async {
    try {
      final preferences = await settings.load();
      filePreferences.load(preferences['files']);
      exportPreferences = ExportPreferences.fromJson(preferences['export']);
      watermark = WatermarkPreferences.fromJson(preferences['watermark']);
      imagePreferences = ImagePreferences.fromJson(preferences['images']);
      _blank.format = filePreferences.newDocumentFormat;
      final savedPalette = preferences['palette'];
      if (savedPalette is String && paletteNames.containsKey(savedPalette)) {
        palette = savedPalette;
      }
      layout =
          WorkspaceLayout.values
              .where((l) => l.name == preferences['layout'])
              .firstOrNull ??
          layout;
      typography =
          MarkdownTypography.values
              .where((t) => t.name == preferences['typography'])
              .firstOrNull ??
          typography;
      themeMode =
          ThemeMode.values
              .where((t) => t.name == preferences['theme'])
              .firstOrNull ??
          themeMode;
      language = languageNames.containsKey(preferences['language'])
          ? preferences['language']! as String
          : language;
      if (!documents.contains(_blank)) _blank.name = strings.untitledFile;
      guideSeen = preferences['guideSeen'] == true;
      compact = preferences['compact'] == true;
      lineNumbers = preferences['lineNumbers'] != false;
      typewriter = preferences['typewriter'] == true;
      focusMode = preferences['focusMode'] == true;
      editingPreferences = MarkdownEditingPreferences.fromJson(
        preferences['editor'],
      );
      markdownPreferences = MarkdownPreferences.fromJson(
        preferences['markdown'],
      );
      contentZoom = (preferences['contentZoom'] as num? ?? 1).toDouble().clamp(
        .9,
        1.25,
      );
      statusbar = preferences['statusbar'] != false;
      motion = preferences['motion'] != false;
      sidebarWidth = (preferences['sidebarWidth'] as num? ?? 226)
          .toDouble()
          .clamp(200, 560);
      summaryLength = (preferences['summaryLength'] as num? ?? 30)
          .toInt()
          .clamp(1, 120);
      paragraphs = preferences['paragraphs'] != false;
      lists = preferences['lists'] != false;
      blocks = preferences['blocks'] == true;
      _map.setMode(
        MindMapLayoutMode.values
                .where((mode) => mode.name == preferences['mapMode'])
                .firstOrNull ??
            MindMapLayoutMode.right,
      );
      fontSize = (preferences['fontSize'] as num? ?? 16).toDouble().clamp(
        12,
        24,
      );
      final paths = preferences['recent'];
      if (paths is List) recent.addAll(paths.whereType<String>().take(20));
      if (filePreferences.recovery) recoverable = await recovery.load();
      if (filePreferences.restoreWorkspace) {
        final workspace = preferences['workspace'];
        if (workspace is Map) await _restoreWorkspace(workspace);
      }
      await mcp.load(preferences['mcp']);
    } catch (error) {
      _statusMessage = (l) => l.preferencesLoadFailed(error.toString());
    }
    ready = true;
    _refreshMap();
    _notify();
    if (watchFiles) {
      _externalTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(checkExternal()),
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _add(WorkspaceDocument document) {
    documents.add(document);
    document.editor.addListener(_changed);
  }

  int _mapRevision = -1;
  String? _mapDocument;
  void _changed() {
    if (_disposed) return;
    if (!_guiding &&
        identical(current, _blank) &&
        editor.text.isNotEmpty &&
        !documents.contains(_blank)) {
      documents.add(_blank);
    }
    if (_mapDocument != current.id || _mapRevision != editor.session.revision) {
      _refreshMap();
      search(findQuery);
      _recoveryTimer?.cancel();
      if (!_guiding) {
        if (filePreferences.recovery) {
          _recoveryTimer = Timer(
            const Duration(milliseconds: 600),
            () => unawaited(flushRecovery()),
          );
        }
        _scheduleSave(current);
      }
    }
    _notify();
  }

  void _refreshMap() {
    _mapRevision = editor.session.revision;
    _mapDocument = current.id;
    _map.setRoot(_tree());
  }

  MindMapNode _tree() {
    _headingForNode.clear();
    final doc = current.editor.document;
    final first = doc.headings.firstOrNull;
    final rootHeading = first?.level == 1 ? first : null;
    final contentByHeading = <String?, List<MarkdownBlock>>{};
    final childrenByHeading = <String?, List<MarkdownHeading>>{};
    for (final heading in doc.headings) {
      (childrenByHeading[heading.parentId] ??= []).add(heading);
    }
    var headingIndex = -1;
    for (final block in doc.blocks) {
      while (headingIndex + 1 < doc.headings.length &&
          doc.headings[headingIndex + 1].header.start <= block.range.start) {
        headingIndex++;
      }
      if (block.kind == MarkdownBlockKind.heading) continue;
      final owner = headingIndex < 0 ? null : doc.headings[headingIndex].id;
      (contentByHeading[owner] ??= []).add(block);
    }
    List<MindMapNode> content(MarkdownHeading? heading) {
      final result = <MindMapNode>[];
      for (final block in contentByHeading[heading?.id] ?? <MarkdownBlock>[]) {
        final include = switch (block.kind) {
          MarkdownBlockKind.paragraph => paragraphs,
          MarkdownBlockKind.list => lists,
          MarkdownBlockKind.code ||
          MarkdownBlockKind.math ||
          MarkdownBlockKind.table ||
          MarkdownBlockKind.quote => blocks,
          _ => false,
        };
        if (!include) continue;
        final plain = block.range
            .slice(doc.source)
            .replaceAll(RegExp(r'[#*`>\[\]]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final title = plain.characters.take(summaryLength).join();
        final id = 'body-${block.range.start}';
        if (heading != null) _headingForNode[id] = heading.id;
        result.add(
          MindMapNode(
            id: id,
            title:
                '$title${plain.characters.length > summaryLength ? '…' : ''}',
            summary: true,
          ),
        );
      }
      return result;
    }

    MindMapNode node(MarkdownHeading heading) {
      _headingForNode[heading.id] = heading.id;
      return MindMapNode(
        id: heading.id,
        title: heading.title.isEmpty ? strings.untitled : heading.title,
        subtitle: strings.sectionLevel(heading.level),
        children: [
          ...content(heading),
          ...?childrenByHeading[heading.id]?.map(node),
        ],
      );
    }

    if (rootHeading != null) _headingForNode[current.id] = rootHeading.id;
    return MindMapNode(
      id: current.id,
      title:
          rootHeading?.title ?? current.name.replaceFirst(RegExp(r'\.md$'), ''),
      subtitle: strings.markdownDocument,
      children: [
        ...content(rootHeading),
        ...doc.headings
            .where(
              (h) =>
                  h != rootHeading &&
                  (h.parentId == rootHeading?.id || (h.parentId == null)),
            )
            .map(node),
      ],
    );
  }

  void selectNode(MindMapNode node) {
    selectedHeadingId = _headingForNode[node.id];
    final heading = selectedHeading;
    if (heading != null) editor.reveal(heading.header.start);
    _notify();
  }

  MarkdownHeading? get selectedHeading => selectedHeadingId == null
      ? null
      : editor.document.heading(selectedHeadingId!);
  void selectHeading(MarkdownHeading heading) {
    selectedHeadingId = heading.id;
    editor.reveal(heading.header.start, end: heading.header.end);
    map.select(heading.id);
    _notify();
  }

  bool followAnchor(String href) {
    if (!href.startsWith('#')) return false;
    final String fragment;
    try {
      fragment = Uri.decodeComponent(Uri.parse(href).fragment);
    } on FormatException {
      return false;
    }
    if (fragment.isEmpty) {
      _statusMessage = null;
      selectedHeadingId = null;
      map.select(null);
      editor.reveal(0);
      _notify();
      return true;
    }
    final heading = markdownHeadingAnchors(
      editor.document,
      preferences: markdownPreferences,
    )[fragment];
    if (heading == null) {
      _statusMessage = (l) => l.anchorNotFound(fragment);
      _notify();
      return false;
    }
    _statusMessage = null;
    selectHeading(heading);
    return true;
  }

  void moveNode(String source, String target) {
    final from = _headingForNode[source], to = _headingForNode[target];
    if (from != null && to != null) editor.session.reparentHeading(from, to);
  }

  void renameNode(MindMapNode node, String title) {
    final id = _headingForNode[node.id];
    if (id != null && !node.summary) editor.session.renameHeading(id, title);
  }

  void setLayout(WorkspaceLayout value) {
    layout = value;
    _notify();
    persist();
  }

  void updateAppearance({
    String? palette,
    ThemeMode? mode,
    MarkdownTypography? typography,
    bool? compact,
    String? language,
    bool? lineNumbers,
    double? fontSize,
    double? contentZoom,
    bool? statusbar,
    bool? motion,
  }) {
    this.palette = palette ?? this.palette;
    themeMode = mode ?? themeMode;
    this.typography = typography ?? this.typography;
    this.compact = compact ?? this.compact;
    if (language != null &&
        languageNames.containsKey(language) &&
        language != this.language) {
      this.language = language;
      _refreshMap();
    }
    this.lineNumbers = lineNumbers ?? this.lineNumbers;
    this.fontSize = (fontSize ?? this.fontSize).clamp(12, 24);
    this.contentZoom = (contentZoom ?? this.contentZoom).clamp(.9, 1.25);
    this.statusbar = statusbar ?? this.statusbar;
    this.motion = motion ?? this.motion;
    _notify();
    persist();
  }

  void updateEditorPreferences({
    MarkdownBodyFont? font,
    double? codeSize,
    int? indent,
    bool? autoPair,
    bool? codeWrap,
  }) {
    editingPreferences = editingPreferences.copyWith(
      font: font,
      codeSize: codeSize,
      indent: indent,
      autoPair: autoPair,
      codeWrap: codeWrap,
    );
    _notify();
    persist();
  }

  void updateMarkdownPreferences(MarkdownPreferences value) {
    markdownPreferences = value;
    _notify();
    persist();
  }

  void updateExportPreferences({
    String? format,
    String? folder,
    bool? openAfterExport,
    ExportPaper? paper,
    double? margin,
    bool? htmlStyle,
  }) {
    exportPreferences = exportPreferences.copyWith(
      format: format,
      folder: folder,
      openAfterExport: openAfterExport,
      paper: paper,
      margin: margin,
      htmlStyle: htmlStyle,
    );
    _notify();
    persist();
  }

  void updateWatermark({
    bool? preview,
    bool? export,
    String? text,
    double? opacity,
  }) {
    watermark = watermark.copyWith(
      preview: preview,
      export: export,
      text: text,
      opacity: opacity,
    );
    _notify();
    persist();
  }

  void updateImagePreferences({bool? copy, bool? relative, String? folder}) {
    imagePreferences = imagePreferences.copyWith(
      copy: copy,
      relative: relative,
      folder: folder,
    );
    _notify();
    persist();
  }

  bool _insertingImage = false;
  Future<void> insertImage() async {
    if (_insertingImage) return;
    _insertingImage = true;
    final document = current, controller = editor;
    final revision = controller.session.revision;
    final selection = controller.selection;
    try {
      final image = await imageAssets.pick();
      if (image == null || _disposed) return;
      void checkDocument() {
        if (_disposed ||
            !identical(current, document) ||
            controller.session.revision != revision) {
          throw StateError(strings.documentChanged);
        }
      }

      checkDocument();
      final markdown = await imageAssets.markdown(
        image,
        documentPath: document.path,
        preferences: imagePreferences,
      );
      checkDocument();
      if (selection.isValid) {
        controller.select(selection.baseOffset, selection.extentOffset);
      }
      controller.replaceSelection(markdown);
    } finally {
      _insertingImage = false;
    }
  }

  void setSummary({
    int? length,
    bool? paragraphs,
    bool? lists,
    bool? blocks,
    MindMapLayoutMode? mode,
  }) {
    summaryLength = (length ?? summaryLength).clamp(1, 120);
    this.paragraphs = paragraphs ?? this.paragraphs;
    this.lists = lists ?? this.lists;
    this.blocks = blocks ?? this.blocks;
    if (mode != null) _map.setMode(mode);
    _refreshMap();
    _notify();
    persist();
  }

  void toggleSidebar() {
    sidebar = !sidebar;
    _notify();
  }

  void setOutline(bool value) {
    outline = value;
    _notify();
  }

  void setFilter(String value) {
    filter = value;
    _notify();
  }

  void resizeSidebar(double value) {
    sidebarWidth = value.clamp(200, 560);
    _notify();
  }

  void toggleFocus() {
    focusMode = !focusMode;
    _notify();
    persist();
  }

  void toggleTypewriter() {
    typewriter = !typewriter;
    _notify();
    persist();
  }

  void togglePresentation({bool outline = true}) {
    if (presenter != null) {
      presenter!.dispose();
      presenter = null;
    } else {
      if (_guiding) endGuide();
      presenter = PresentationController(
        PresentationDeck.fromDocument(editor.document, title: current.name),
        headingId: selectedHeadingId,
        mapMode: layout == WorkspaceLayout.map,
      );
      if (!outline) presenter!.toggleOutline();
    }
    _notify();
  }

  void showFind({bool replace = false}) {
    findVisible = true;
    replaceVisible = replace;
    _notify();
  }

  void closeFind() {
    findVisible = false;
    _notify();
  }

  void search(String query, {bool? matchCase, bool? regex, bool? wholeWord}) {
    findQuery = query;
    this.matchCase = matchCase ?? this.matchCase;
    this.regex = regex ?? this.regex;
    this.wholeWord = wholeWord ?? this.wholeWord;
    try {
      matches = editor.find(
        query,
        caseSensitive: this.matchCase,
        regularExpression: this.regex,
        wholeWord: this.wholeWord,
      );
      _invalidRegex = false;
    } on FormatException {
      _invalidRegex = true;
      matches = [];
    }
    if (matchIndex >= matches.length) matchIndex = -1;
    _notify();
  }

  void nextMatch([int direction = 1]) {
    if (matches.isEmpty) return;
    matchIndex = (matchIndex + direction) % matches.length;
    final match = matches[matchIndex];
    editor.reveal(match.start, end: match.end);
    if (!layout.panes.contains('source')) {
      setLayout(WorkspaceLayout.sourceRender);
    }
    editor.sourceFocus.requestFocus();
    _notify();
  }

  void replaceMatches(String value) {
    if (findError != null) return;
    editor.replaceAll(
      findQuery,
      value,
      caseSensitive: matchCase,
      regularExpression: regex,
      wholeWord: wholeWord,
    );
    search(findQuery);
  }

  void replaceCurrent(String value) {
    if (matchIndex < 0 || matchIndex >= matches.length) {
      nextMatch();
      return;
    }
    final match = matches[matchIndex];
    editor.session.patch(TextPatch(match, value), label: '替换');
    search(findQuery);
    nextMatch();
  }

  void switchDocument(WorkspaceDocument document) {
    endGuide();
    if (_guiding) endGuide();
    presenter?.dispose();
    presenter = null;
    current = document;
    selectedHeadingId = null;
    externalChange = null;
    _refreshMap();
    search(findQuery);
    _notify();
    persist();
  }

  void newDocument() {
    endGuide();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final doc = WorkspaceDocument(
      id: id,
      name: strings.untitledFile,
      text: '',
      format: filePreferences.newDocumentFormat,
    );
    _add(doc);
    switchDocument(doc);
  }

  void openMermaidExamples() {
    newDocument();
    current.name = '${strings.mermaidExamples}.md';
    final chinese = language.startsWith('zh');
    final content = StringBuffer('# ${strings.mermaidExamples}\n');
    for (var group = 0; group < 4; group++) {
      content.writeln('\n## ${MermaidTemplate.groupLabel(group, chinese)}');
      for (final template in MermaidTemplate.values.where(
        (t) => t.group == group,
      )) {
        content.writeln('\n### ${template.label(chinese)}${template.markdown}');
      }
    }
    editor.session.replace(content.toString(), label: strings.mermaidExamples);
    editor.select(0);
    setLayout(WorkspaceLayout.instant);
  }

  Future<void> open() async {
    final opened = await files.pick();
    if (opened != null) acceptOpened(opened);
  }

  Future<void> openPath(String path) async =>
      acceptOpened(await files.read(path));
  void acceptOpened(OpenedDocument opened) {
    endGuide();
    final existing = documents
        .where(
          (d) => opened.path != null && p.equals(d.path ?? '', opened.path!),
        )
        .firstOrNull;
    if (existing != null) {
      switchDocument(existing);
      return;
    }
    final doc = WorkspaceDocument(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: opened.name,
      text: opened.text,
      path: opened.path,
      persistedText: opened.text,
      format: opened.format,
    );
    _add(doc);
    switchDocument(doc);
    if (opened.path != null) _remember(opened.path!);
  }

  Future<void> openFolder() async {
    final selected = await files.folder();
    if (selected == null) return;
    folder = selected;
    sidebar = true;
    outline = false;
    _notify();
    persist();
  }

  Future<void> _restoreWorkspace(Map workspace) async {
    final paths = workspace['paths'];
    if (paths is List) {
      for (final path in paths.whereType<String>().take(40)) {
        try {
          final opened = await files.read(path);
          _add(
            WorkspaceDocument(
              id: 'restored-${documents.length}',
              name: opened.name,
              path: opened.path,
              text: opened.text,
              persistedText: opened.text,
              format: opened.format,
            ),
          );
        } on FileSystemException {
          // Missing recent files must not prevent other documents restoring.
        } on FormatException {
          // Leave unrecognized files untouched rather than loading replacements.
        }
      }
    }
    current =
        documents.where((d) => d.path == workspace['active']).firstOrNull ??
        documents.firstOrNull ??
        _blank;
    final folderPath = workspace['folder'];
    if (folderPath is String) {
      try {
        folder = await files.readFolder(folderPath);
      } on FileSystemException {
        // The directory may have moved since the previous run.
      }
    }
  }

  Future<void> updateFilePreferences({
    bool? autoSave,
    bool? recovery,
    bool? restoreWorkspace,
    int? saveDelay,
    DocumentEncoding? encoding,
    DocumentNewline? newline,
  }) async {
    final prefs = filePreferences;
    prefs.autoSave = autoSave ?? prefs.autoSave;
    prefs.recovery = recovery ?? prefs.recovery;
    prefs.restoreWorkspace = restoreWorkspace ?? prefs.restoreWorkspace;
    if (saveDelay != null && [2, 5, 10].contains(saveDelay)) {
      prefs.saveDelay = saveDelay;
    }
    prefs.newDocumentFormat = TextFileFormat(
      encoding: encoding ?? prefs.newDocumentFormat.encoding,
      newline: newline ?? prefs.newDocumentFormat.newline,
    );
    if (documents.isEmpty) _blank.format = prefs.newDocumentFormat;
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
    for (final doc in documents) {
      _scheduleSave(doc);
    }
    _recoveryTimer?.cancel();
    _notify();
    persist();
    if (!prefs.recovery) recoverable.clear();
    await flushRecovery();
  }

  void _scheduleSave(WorkspaceDocument doc) {
    _saveTimers.remove(doc)?.cancel();
    if (!filePreferences.autoSave ||
        doc.path == null ||
        !doc.editor.session.isDirty ||
        _guiding) {
      return;
    }
    _saveTimers[doc] = Timer(Duration(seconds: filePreferences.saveDelay), () {
      _saveTimers.remove(doc);
      if (_disposed || !documents.contains(doc)) return;
      unawaited(
        _saveDocument(doc).catchError((Object error) {
          _statusMessage = error is FileConflict
              ? (l) => l.fileConflict
              : (l) => l.operationFailed(error.toString());
          if (identical(doc, current)) unawaited(checkExternal());
          _notify();
          return false;
        }),
      );
    });
  }

  Future<bool> save({bool saveAs = false}) =>
      _saveDocument(current, saveAs: saveAs);

  Future<void> finishPendingSaves() async {
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
    await Future.wait(_saveQueues.values.toList());
    await _preferencesWrite;
  }

  Future<bool> _saveDocument(WorkspaceDocument doc, {bool saveAs = false}) {
    final text = doc.editor.text;
    _saveTimers.remove(doc)?.cancel();
    // A manual save and a pending autosave share one ordered queue per document.
    final task = (_saveQueues[doc] ?? Future.value(true))
        .catchError((Object _) => false)
        .then((_) => _writeDocument(doc, text, saveAs: saveAs));
    _saveQueues[doc] = task;
    unawaited(
      task.then(
        (_) {
          if (identical(_saveQueues[doc], task)) _saveQueues.remove(doc);
        },
        onError: (Object _, StackTrace _) {
          if (identical(_saveQueues[doc], task)) _saveQueues.remove(doc);
        },
      ),
    );
    return task;
  }

  Future<bool> _writeDocument(
    WorkspaceDocument doc,
    String text, {
    required bool saveAs,
  }) async {
    if (_guiding) {
      _statusMessage = (l) => l.finishGuideBeforeSaving;
      _notify();
      return false;
    }
    if (!saveAs && doc.path != null) {
      await files.write(
        doc.path!,
        text,
        expected: doc.persistedText,
        format: doc.format,
      );
    } else {
      final path = await files.saveAs(
        doc.name,
        await encodeDocument(text, doc.format),
        dialogTitle: strings.saveNamedFile(doc.name),
      );
      if (path == null) return false;
      if (!Platform.isAndroid && !Platform.isIOS) {
        doc.path = path;
        _remember(path);
      }
      if (!Platform.isAndroid && !Platform.isIOS) doc.name = p.basename(path);
    }
    doc.persistedText = text;
    if (!documents.contains(doc)) documents.add(doc);
    doc.editor.session.markSaved(savedText: text);
    if (identical(doc, current)) externalChange = null;
    final savedName = doc.name;
    _statusMessage = (l) => l.savedFile(savedName);
    persist();
    await flushRecovery();
    _notify();
    return true;
  }

  void _remember(String path) {
    recent
      ..remove(path)
      ..insert(0, path);
    if (recent.length > 20) recent.removeRange(20, recent.length);
    persist();
  }

  Future<void> closeCurrent({bool keepDraft = false}) async {
    endGuide();
    final document = current;
    _saveTimers.remove(document)?.cancel();
    await _saveQueues[document]?.catchError((Object _) => false);
    if (keepDraft && filePreferences.recovery && editor.session.isDirty) {
      recoverable.add({
        'name': document.name,
        'path': document.path,
        'text': editor.text,
        'saved': document.persistedText ?? '',
        ...document.format.toJson(),
      });
    }
    documents.remove(document);
    document.editor.removeListener(_changed);
    document.dispose();
    if (identical(document, _blank)) {
      _blank = WorkspaceDocument(
        id: 'empty-workspace',
        name: strings.untitledFile,
        text: '',
        format: filePreferences.newDocumentFormat,
      );
      _blank.editor.addListener(_changed);
    }
    current = documents.firstOrNull ?? _blank;
    selectedHeadingId = null;
    externalChange = null;
    _refreshMap();
    search(findQuery);
    _notify();
    persist();
    await flushRecovery(throwOnError: true);
  }

  Future<void> checkExternal() async {
    if (_checking || _disposed || current.path == null || _guiding) return;
    _checking = true;
    final doc = current;
    try {
      final latest = await files.read(doc.path!);
      if (!_disposed && identical(doc, current)) {
        final next = latest.text != normalizeNewlines(doc.persistedText ?? '')
            ? latest
            : null;
        if (next?.text != externalChange?.text) {
          externalChange = next;
          _notify();
        }
      }
    } catch (error) {
      _statusMessage = (l) => l.fileReadFailed(error.toString());
      _notify();
    } finally {
      _checking = false;
    }
  }

  void reloadExternal() {
    final change = externalChange;
    if (change == null) return;
    editor.session.replace(change.text, label: '载入外部修改');
    editor.session.markSaved();
    current.persistedText = change.text;
    current.format = change.format;
    externalChange = null;
    _notify();
  }

  Future<void> flushRecovery({bool throwOnError = false}) async {
    if (_guiding) return;
    final snapshots = documents
        .where((d) => d.editor.session.isDirty)
        .map(
          (d) => <String, Object?>{
            'name': d.name,
            'path': d.path,
            'text': d.editor.session.text,
            'saved': d.persistedText ?? '',
            ...d.format.toJson(),
          },
        )
        .toList();
    try {
      await recovery.save(
        filePreferences.recovery ? [...recoverable, ...snapshots] : [],
      );
    } catch (error) {
      _statusMessage = (l) => l.recoverySaveFailed(error.toString());
      _notify();
      if (throwOnError) rethrow;
    }
  }

  void restoreDrafts() {
    for (final draft in recoverable) {
      if (draft['text'] is! String) continue;
      final doc = WorkspaceDocument(
        id: 'recovered-${DateTime.now().microsecondsSinceEpoch}-${documents.length}',
        name: draft['name'] as String? ?? strings.recoveredDraftFile,
        path: draft['path'] as String?,
        text: draft['saved'] as String? ?? '',
        persistedText: draft['saved'] as String?,
        format: TextFileFormat.fromJson(draft),
      );
      doc.editor.session.replace(draft['text']! as String, label: '恢复草稿');
      _add(doc);
      current = doc;
    }
    recoverable = [];
    _refreshMap();
    _notify();
  }

  Future<void> discardDrafts() async {
    recoverable = [];
    await recovery.save([]);
    _notify();
  }

  void persist() {
    if (_guiding) return;
    final revision = ++_preferencesRevision;
    preferencesSaving = true;
    preferencesError = null;
    _preferencesWrite = settings
        .save({
          'palette': palette,
          'theme': themeMode.name,
          'layout': _layout.name,
          'typography': typography.name,
          'language': language,
          'compact': compact,
          'lineNumbers': lineNumbers,
          'typewriter': typewriter,
          'focusMode': focusMode,
          'fontSize': fontSize,
          'editor': editingPreferences.toJson(),
          'markdown': markdownPreferences.toJson(),
          'contentZoom': contentZoom,
          'statusbar': statusbar,
          'motion': motion,
          'sidebarWidth': sidebarWidth,
          'summaryLength': summaryLength,
          'paragraphs': paragraphs,
          'lists': lists,
          'blocks': blocks,
          'mapMode': _map.mode.name,
          'recent': List.of(recent),
          'guideSeen': guideSeen,
          'mcp': mcp.preferences,
          'files': filePreferences.toJson(),
          'export': exportPreferences.toJson(),
          'watermark': watermark.toJson(),
          'images': imagePreferences.toJson(),
          'workspace': {
            'paths': documents.map((d) => d.path).whereType<String>().toList(),
            'active': current.path,
            'folder': folder?.path,
          },
        })
        .then((_) {
          if (revision != _preferencesRevision) return;
          preferencesSaving = false;
          _notify();
        })
        .catchError((Object error) {
          if (revision != _preferencesRevision) return;
          preferencesSaving = false;
          preferencesError = error.toString();
          _statusMessage = (l) => l.preferencesSaveFailed(error.toString());
          _notify();
        });
    _notify();
  }

  bool _guiding = false;
  bool guideSeen = false;
  bool get guiding => _guiding;
  int guideStep = 0;
  MarkdownSnapshot? _guideSnapshot;
  WorkspaceLayout? _guideLayout;
  TextSelection? _guideSelection;
  MarkdownTypography? _guideTypography;
  bool _guideCompact = false;
  void startGuide() {
    if (_guiding) return;
    _guideSnapshot = editor.session.snapshot();
    _guideSelection = editor.selection;
    _guideTypography = typography;
    _guideCompact = compact;
    _guideLayout = _layout;
    _guiding = true;
    guideStep = 0;
    editor.session.replace(strings.guideDocument, label: '引导演练');
    layout = WorkspaceLayout.instant;
    _notify();
  }

  void advanceGuide(int step) {
    guideStep = step.clamp(0, 5);
    layout = switch (guideStep) {
      1 => WorkspaceLayout.sourceRender,
      2 || 3 =>
        viewport == WorkspaceViewport.phone
            ? WorkspaceLayout.map
            : WorkspaceLayout.instantMap,
      4 => WorkspaceLayout.read,
      _ => WorkspaceLayout.instant,
    };
    _notify();
  }

  void endGuide() {
    if (!_guiding) return;
    editor.session.restore(_guideSnapshot!);
    final selection = _guideSelection;
    if (selection != null && selection.isValid) {
      editor.select(selection.baseOffset, selection.extentOffset);
    }
    typography = _guideTypography!;
    compact = _guideCompact;
    layout = _guideLayout!;
    _guiding = false;
    guideSeen = true;
    _guideSnapshot = null;
    _scheduleSave(current);
    persist();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    mcp.dispose();
    presenter?.dispose();
    _recoveryTimer?.cancel();
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _externalTimer?.cancel();
    for (final doc in documents) {
      doc.editor.removeListener(_changed);
      doc.dispose();
    }
    if (!documents.contains(_blank)) {
      _blank.editor.removeListener(_changed);
      _blank.dispose();
    }
    map.dispose();
    super.dispose();
  }
}
