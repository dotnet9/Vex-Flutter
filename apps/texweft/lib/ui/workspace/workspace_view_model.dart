import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:texweft_editor/texweft_editor.dart';
import 'package:texweft_markdown_core/texweft_markdown_core.dart';
import 'package:texweft_mindmap/texweft_mindmap.dart';

import '../../data/repositories/recovery_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/file_service.dart';
import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/palette_tokens.dart';

final class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel({
    required this.files,
    required this.settings,
    required this.recovery,
    String initialLanguage = 'zh',
  }) : language = languageNames.containsKey(initialLanguage)
           ? initialLanguage
           : 'en' {
    _addSamples();
    current = documents.first;
    _map = MindMapController(_tree());
  }

  void _addSamples() {
    for (final entry in strings.sampleDocuments.entries) {
      _add(
        WorkspaceDocument(
          id: 'sample-${documents.length}',
          name: entry.key,
          text: entry.value,
          demo: true,
        ),
      );
    }
  }

  AppLocalizations get strings => stringsForLanguage(language);
  final DocumentFileService files;
  final SettingsRepository settings;
  final RecoveryRepository recovery;
  final documents = <WorkspaceDocument>[];
  final recent = <String>[];
  final folderPaths = <String>[];
  String? _folderName;
  String? get folderName =>
      _folderName == '' ? strings.emptyFolder : _folderName;
  late WorkspaceDocument current;
  late final MindMapController _map;
  MindMapController get map => _map;
  MarkdownEditorController get editor => current.editor;
  WorkspaceLayout layout = WorkspaceLayout.instant;
  MarkdownTypography typography = MarkdownTypography.simple;
  ThemeMode themeMode = ThemeMode.light;
  String palette = 'weft', language;
  bool sidebar = true, outline = false, compact = false, lineNumbers = true;
  bool findVisible = false,
      replaceVisible = false,
      focusMode = false,
      presentation = false;
  bool paragraphs = true, lists = true, blocks = false;
  int summaryLength = 30;
  double sidebarWidth = 226, fontSize = 14;
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
  Timer? _autosave, _externalTimer;
  final _headingForNode = <String, String>{};
  List<Map<String, Object?>> recoverable = [];

  Future<void> initialize({bool watchFiles = true}) async {
    try {
      final preferences = await settings.load();
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
      final previousLanguage = language;
      language = languageNames.containsKey(preferences['language'])
          ? preferences['language']! as String
          : language;
      // Only replace untouched built-in samples during initial preference loading.
      // Changing the interface language later never rewrites a document.
      if (language != previousLanguage &&
          documents.every((d) => d.demo && !d.editor.session.isDirty)) {
        for (final doc in documents) {
          doc.editor.removeListener(_changed);
          doc.dispose();
        }
        documents.clear();
        _addSamples();
        current = documents.first;
      }
      compact = preferences['compact'] == true;
      lineNumbers = preferences['lineNumbers'] != false;
      sidebarWidth = (preferences['sidebarWidth'] as num? ?? 226)
          .toDouble()
          .clamp(200, 560);
      summaryLength = (preferences['summaryLength'] as num? ?? 30)
          .toInt()
          .clamp(1, 120);
      paragraphs = preferences['paragraphs'] != false;
      lists = preferences['lists'] != false;
      blocks = preferences['blocks'] == true;
      fontSize = (preferences['fontSize'] as num? ?? 14).toDouble().clamp(
        12,
        22,
      );
      final paths = preferences['recent'];
      if (paths is List) recent.addAll(paths.whereType<String>().take(20));
      recoverable = await recovery.load();
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
    if (_mapDocument != current.id || _mapRevision != editor.session.revision) {
      _refreshMap();
      search(findQuery);
      _autosave?.cancel();
      if (!_guiding) {
        _autosave = Timer(
          const Duration(milliseconds: 600),
          () => unawaited(flushRecovery()),
        );
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
    List<MindMapNode> content(MarkdownHeading? heading) {
      final range =
          heading?.body ??
          SourceRange(
            0,
            doc.headings.firstOrNull?.header.start ?? doc.source.length,
          );
      final result = <MindMapNode>[];
      for (final block in doc.blocks.where(
        (b) =>
            range.contains(b.range.start) &&
            b.kind != MarkdownBlockKind.heading,
      )) {
        final include = switch (block.kind) {
          MarkdownBlockKind.paragraph => paragraphs,
          MarkdownBlockKind.list => lists,
          MarkdownBlockKind.code ||
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
          ...doc.headings.where((h) => h.parentId == heading.id).map(node),
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
    if (heading != null) editor.select(heading.header.start);
    _notify();
  }

  MarkdownHeading? get selectedHeading => selectedHeadingId == null
      ? null
      : editor.document.heading(selectedHeadingId!);
  void selectHeading(MarkdownHeading heading) {
    selectedHeadingId = heading.id;
    editor.select(heading.header.start, heading.header.end);
    map.select(heading.id);
    _notify();
  }

  void moveNode(String source, String target) {
    final from = _headingForNode[source], to = _headingForNode[target];
    if (from != null && to != null) editor.session.reparentHeading(from, to);
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
    this.fontSize = fontSize ?? this.fontSize;
    _notify();
    persist();
  }

  void setSummary({int? length, bool? paragraphs, bool? lists, bool? blocks}) {
    summaryLength = (length ?? summaryLength).clamp(1, 120);
    this.paragraphs = paragraphs ?? this.paragraphs;
    this.lists = lists ?? this.lists;
    this.blocks = blocks ?? this.blocks;
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
  }

  void togglePresentation() {
    presentation = !presentation;
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
    editor.select(match.start, match.end);
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
    if (_guiding) endGuide();
    current = document;
    selectedHeadingId = null;
    externalChange = null;
    _refreshMap();
    search(findQuery);
    _notify();
  }

  void newDocument() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final doc = WorkspaceDocument(id: id, name: strings.untitledFile, text: '');
    _add(doc);
    switchDocument(doc);
  }

  Future<void> open() async {
    final opened = await files.pick();
    if (opened != null) acceptOpened(opened);
  }

  Future<void> openPath(String path) async =>
      acceptOpened(await files.read(path));
  void acceptOpened(OpenedDocument opened) {
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
    );
    _add(doc);
    switchDocument(doc);
    if (opened.path != null) _remember(opened.path!);
  }

  Future<void> openFolder() async {
    final paths = await files.folder();
    if (paths == null) return;
    folderPaths
      ..clear()
      ..addAll(paths);
    _folderName = paths.isEmpty ? '' : p.basename(p.dirname(paths.first));
    sidebar = true;
    outline = false;
    _notify();
  }

  Future<bool> save({bool saveAs = false}) async {
    if (_guiding) {
      _statusMessage = (l) => l.finishGuideBeforeSaving;
      _notify();
      return false;
    }
    final doc = current, text = editor.session.text;
    if (!saveAs && doc.path != null) {
      await files.write(doc.path!, text, expected: doc.persistedText);
    } else {
      final path = await files.saveAs(
        doc.name,
        Uint8List.fromList(utf8.encode(text)),
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
    doc.editor.session.markSaved(savedText: text);
    externalChange = null;
    final savedName = doc.name;
    _statusMessage = (l) => l.savedFile(savedName);
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

  Future<void> checkExternal() async {
    if (_checking || _disposed || current.path == null || _guiding) return;
    _checking = true;
    final doc = current;
    try {
      final latest = await files.read(doc.path!);
      if (!_disposed && identical(doc, current)) {
        final next = latest.text != doc.persistedText ? latest : null;
        if (next?.text != externalChange?.text) {
          externalChange = next;
          _notify();
        }
      }
    } on FileSystemException catch (error) {
      _statusMessage = (l) => l.fileReadFailed(error.message);
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
    externalChange = null;
    _notify();
  }

  Future<void> flushRecovery() async {
    if (_guiding) return;
    final snapshots = documents
        .where((d) => d.editor.session.isDirty)
        .map(
          (d) => <String, Object?>{
            'name': d.name,
            'path': d.path,
            'text': d.editor.session.text,
            'saved': d.persistedText ?? '',
          },
        )
        .toList();
    try {
      await recovery.save([...recoverable, ...snapshots]);
    } catch (error) {
      _statusMessage = (l) => l.recoverySaveFailed(error.toString());
      _notify();
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
    unawaited(
      settings
          .save({
            'palette': palette,
            'theme': themeMode.name,
            'layout': layout.name,
            'typography': typography.name,
            'language': language,
            'compact': compact,
            'lineNumbers': lineNumbers,
            'fontSize': fontSize,
            'sidebarWidth': sidebarWidth,
            'summaryLength': summaryLength,
            'paragraphs': paragraphs,
            'lists': lists,
            'blocks': blocks,
            'recent': List.of(recent),
          })
          .catchError((Object error) {
            _statusMessage = (l) => l.preferencesSaveFailed(error.toString());
            _notify();
          }),
    );
  }

  bool _guiding = false;
  bool get guiding => _guiding;
  int guideStep = 0;
  MarkdownSnapshot? _guideSnapshot;
  WorkspaceLayout? _guideLayout;
  void startGuide() {
    if (_guiding) return;
    _guideSnapshot = editor.session.snapshot();
    _guideLayout = layout;
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
      2 || 3 => WorkspaceLayout.instantMap,
      4 => WorkspaceLayout.read,
      _ => WorkspaceLayout.instant,
    };
    _notify();
  }

  void endGuide() {
    if (!_guiding) return;
    editor.session.restore(_guideSnapshot!);
    layout = _guideLayout!;
    _guiding = false;
    _guideSnapshot = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _autosave?.cancel();
    _externalTimer?.cancel();
    for (final doc in documents) {
      doc.editor.removeListener(_changed);
      doc.dispose();
    }
    map.dispose();
    super.dispose();
  }
}
