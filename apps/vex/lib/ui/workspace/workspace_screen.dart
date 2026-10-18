import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../data/services/file_service.dart';
import '../../data/services/social_copy_service.dart';
import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import '../core/palette_tokens.dart';
import 'builtin_documents.dart';
import 'insert_table_dialog.dart';
import 'mermaid_picker.dart';
import 'preferences_dialog.dart';
import 'workspace_dialogs.dart';
import 'workspace_guide.dart';
import 'workspace_menu.dart';
import 'workspace_menu_widgets.dart';
import 'workspace_panes.dart';
import 'workspace_pickers.dart';
import 'workspace_presentation.dart';
import 'workspace_sidebar.dart';
import 'workspace_touch_menu.dart';
import 'workspace_view_model.dart';
import 'unsaved_dialog.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, this.windowIntegration = false});
  final bool windowIntegration;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with WidgetsBindingObserver, WindowListener {
  final _scaffold = GlobalKey<ScaffoldState>();
  WorkspaceViewModel? _boundVm;
  final _guideEditing = GlobalKey(),
      _guideMap = GlobalKey(),
      _guideMapToolbar = GlobalKey();
  final _guideFileMenu = GlobalKey();
  final _guideSave = GlobalKey();
  final _guideSidebar = GlobalKey(), _guideMobileViews = GlobalKey();
  final _guideLayoutPopup = GlobalKey(), _guideTypographyPopup = GlobalKey();
  final _guideMapPopup = GlobalKey();
  final _guideFileCommands = GlobalKey(), _guideShareCommands = GlobalKey();
  GlobalKey get _guideCommands =>
      vm.guideStep == 6 ? _guideShareCommands : _guideFileCommands;
  final _guideOverlay = OverlayPortalController();
  int? _preparedGuideStep;
  WorkspaceViewport? _preparedGuideViewport;
  bool _guideTouchMenu = false;
  ModalRoute<String>? _guideTouchRoute;
  int _guideTouchGeneration = 0;
  final _find = TextEditingController(), _replace = TextEditingController();
  final _findFocus = FocusNode();
  final _layoutsMenu = MenuController(), _typographyMenu = MenuController();
  final _mapAppearanceMenu = MenuController();
  final _topMenus = <String, MenuController>{};
  final _compactTopMenus = <String, MenuController>{};
  final _overflowMenu = MenuController();
  bool _overflowedMenus = false;
  (TextStyle, TextScaler, String)? _menuSizingKey;
  (double, double) _menuWidths = (0, 0);
  static const _menuTextStyle = TextStyle(
    fontSize: 14,
    height: 1.4,
    letterSpacing: 0,
  );
  bool _dragging = false, _closing = false, _nativeCloseApproved = false;
  bool _changingPresentation = false;
  bool _maximized = false;
  String _lastNotice = '';
  bool? _presentationWasFullscreen;
  FocusNode? _presentationPreviousFocus;
  WorkspaceViewModel get vm => context.read<WorkspaceViewModel>();
  bool get _macOS => defaultTargetPlatform == TargetPlatform.macOS;
  bool get _desktop => const [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
  List<WorkspaceMenuEntry> _menus(double width) => workspaceMenus(
    vm,
    macOS: _macOS && _desktop && width >= 700,
    desktop: _desktop && width >= 700,
    maxPanes: vm.viewport.maxPanes,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.windowIntegration && _desktop) {
      windowManager.addListener(this);
      unawaited(
        windowManager.isMaximized().then((value) {
          if (mounted) setState(() => _maximized = value);
        }),
      );
    }
  }

  @override
  void dispose() {
    _boundVm?.mcp.confirm = null;
    WidgetsBinding.instance.removeObserver(this);
    if (widget.windowIntegration && _desktop) {
      windowManager.removeListener(this);
    }
    _find.dispose();
    _replace.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_nativeCloseApproved) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(vm.flushRecovery());
    }
    if (state == AppLifecycleState.resumed) unawaited(vm.checkExternal());
  }

  @override
  void onWindowClose() {
    if (!_nativeCloseApproved) unawaited(_close());
  }

  @override
  void onWindowFocus() => unawaited(vm.checkExternal());
  @override
  void onWindowMaximize() => setState(() => _maximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _boundVm = vm;
    vm.mcp.confirm = _confirmMcp;
    final title = context.l10n.appTitle;
    if (widget.windowIntegration && _desktop) {
      unawaited(windowManager.setTitle(title));
    }
  }

  Future<bool> _confirmMcp(String name) async {
    if (!mounted || _closing) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AppDialog(
            title: context.l10n.mcpConfirmTitle,
            actions: [
              AppButton(
                label: context.l10n.cancel,
                onPressed: () => Navigator.pop(context, false),
              ),
              AppButton(
                label: context.l10n.mcpExecute,
                primary: true,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.mcpConfirmBody,
                  style: const TextStyle(fontSize: 14, height: 1.8),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is FileConflict
              ? context.l10n.fileConflict
              : context.l10n.operationFailed(error.toString()),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _run(Future<void> Function() task) async {
    try {
      await task();
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _close() async {
    await _requestClose();
  }

  Future<bool> _requestClose({void Function()? beforeNativeClose}) async {
    if (_closing) return false;
    _closing = true;
    try {
      if (beforeNativeClose != null && widget.windowIntegration && _desktop) {
        await windowManager.focus();
        if (!mounted) return false;
      }
      vm.endGuide();
      final dirty = vm.documents
          .where((d) => d.editor.session.isDirty)
          .toList();
      if (dirty.isNotEmpty) {
        final decision = await showUnsavedDialog(
          context,
          dirty,
          recovery: vm.filePreferences.recovery,
        );
        if (decision == null) {
          _closing = false;
          return false;
        }
        if (decision == 'save') {
          try {
            for (final doc in dirty) {
              vm.switchDocument(doc);
              if (!await vm.save()) {
                _closing = false;
                return false;
              }
            }
            if (!mounted) return false;
            if (vm.documents.any((doc) => doc.editor.session.isDirty)) {
              throw StateError(context.l10n.closeChanged);
            }
          } catch (e) {
            _error(e);
            _closing = false;
            return false;
          }
        }
      }
      final approvedRevisions = {
        for (final doc in vm.documents) doc: doc.editor.session.revision,
      };
      await vm.finishPendingSaves();
      await vm.flushRecovery(throwOnError: true);
      if (!mounted) return false;
      // The main editor remains interactive while disk I/O is pending.
      if (vm.documents.any(
        (doc) =>
            doc.editor.session.isDirty &&
            approvedRevisions[doc] != doc.editor.session.revision,
      )) {
        throw StateError(context.l10n.closeChanged);
      }
      if (widget.windowIntegration && _desktop) {
        // Let the native window process WM_CLOSE before its message loop exits.
        // On Windows destroy() only posts WM_QUIT, leaving a live HWND while the
        // Flutter engine and COM plugins are being torn down.
        _nativeCloseApproved = true;
        await windowManager.setPreventClose(false);
        beforeNativeClose?.call();
        await windowManager.close();
      } else if (Platform.isAndroid) {
        await SystemNavigator.pop();
      }
      return widget.windowIntegration && _desktop || Platform.isAndroid;
    } catch (error) {
      _nativeCloseApproved = false;
      if (widget.windowIntegration && _desktop) {
        await windowManager.setPreventClose(true);
      }
      _error(error);
      return false;
    } finally {
      _closing = false;
    }
  }

  void _format(String command) {
    final e = vm.editor;
    if (command.startsWith('heading-')) {
      e.setParagraph('${'#' * int.parse(command.substring(8))} ');
      return;
    }
    switch (command) {
      case 'bold':
        e.toggleInline('**');
      case 'italic':
        e.toggleInline('*');
      case 'strike':
        e.toggleInline('~~');
      case 'highlight':
        e.toggleInline('==');
      case 'superscript':
        e.toggleInline('^');
      case 'subscript':
        e.toggleInline('~');
      case 'clear':
        e.clearFormatting();
      case 'heading':
        e.setParagraph('## ');
      case 'quote':
        e.setParagraph('> ');
      case 'list':
        e.setParagraph('- ');
      case 'ordered':
        e.setParagraph('1. ');
      case 'task':
        e.setParagraph('- [ ] ');
      case 'link':
        e.surround('[', '](https://)');
      case 'image':
        unawaited(_run(vm.insertImage));
      case 'inline-code':
        e.toggleInline('`');
      case 'code':
        e.insertCodeBlock();
      case 'math':
        e.insertCodeBlock(math: true);
      case 'footnote':
        e.insertFootnote();
      case 'table':
        unawaited(_run(_insertTable));
      case 'rule':
        e.insertBlock('---', label: '插入水平分割线');
      case 'paragraph':
        e.setParagraph('');
    }
  }

  Future<void> _insertTable() async {
    final document = vm.current, editor = vm.editor;
    final source = editor.text, selection = editor.selection;
    final dimensions = await showInsertTableDialog(context);
    if (!mounted ||
        dimensions == null ||
        (!identical(vm.current, document) &&
            !vm.documents.contains(document))) {
      return;
    }
    if (editor.text != source) throw StateError(context.l10n.documentChanged);
    if (selection.isValid) {
      editor.select(selection.baseOffset, selection.extentOffset);
    }
    editor.insertTable(
      rows: dimensions.rows,
      columns: dimensions.columns,
      columnLabel: vm.strings.tableColumn,
    );
  }

  void _action(String action) {
    if (vm.guiding && const ['save', 'save-as', 'save-all'].contains(action)) {
      unawaited(_run(_saveGuideCopy));
      return;
    }
    if (const ['cut', 'paste'].contains(action) &&
        _focusedClipboardAction(action)) {
      return;
    }
    if (workspaceCommandEditsText(action) && !vm.canEditText) return;
    if (action.startsWith('table:')) {
      final target = vm.editor.tableTarget();
      if (target == null) return;
      final command = MarkdownTableCommand.values.byName(action.substring(6));
      if (command == MarkdownTableCommand.copy) {
        unawaited(
          _run(
            () => Clipboard.setData(
              ClipboardData(text: target.block.range.slice(target.source)),
            ),
          ),
        );
      } else {
        try {
          vm.editor.editTable(target, command);
        } catch (error) {
          _error(error);
        }
      }
      return;
    }
    if (action.startsWith('mermaid:')) {
      vm.editor.insertMermaid(
        MermaidTemplate.values.byName(action.substring(8)).source,
      );
      return;
    }
    if (action.startsWith('layout:')) {
      vm.setLayout(WorkspaceLayout.values.byName(action.substring(7)));
      return;
    }
    if (action.startsWith('palette:')) {
      vm.updateAppearance(palette: action.substring(8));
      return;
    }
    if (action.startsWith('theme:')) {
      vm.updateAppearance(mode: ThemeMode.values.byName(action.substring(6)));
      return;
    }
    if (action.startsWith('typography:')) {
      vm.updateAppearance(
        typography: MarkdownTypography.values.byName(action.substring(11)),
      );
      return;
    }
    if (action.startsWith('export:')) {
      unawaited(showExportDialog(context, vm, type: action.substring(7)));
      return;
    }
    if (action.startsWith('publish:')) {
      unawaited(
        _run(
          () => _copyForPublishing(
            PublishingPlatform.values.byName(action.substring(8)),
          ),
        ),
      );
      return;
    }
    if (action.startsWith('open-path:')) {
      unawaited(_run(() => vm.openPath(action.substring(10))));
      return;
    }
    if (action.startsWith('format:')) {
      _format(action.substring(7));
      return;
    }
    switch (action) {
      case 'new-window' || 'document-window':
        unawaited(
          _run(() => _openWindow(currentDocument: action == 'document-window')),
        );
      case 'new':
        vm.newDocument();
      case 'save-all':
        unawaited(
          _run(() async {
            final previous = vm.current;
            for (final document in List.of(vm.documents)) {
              if (!document.editor.session.isDirty) continue;
              vm.switchDocument(document);
              if (!await vm.save()) break;
            }
            if (vm.documents.contains(previous)) vm.switchDocument(previous);
          }),
        );
      case 'close-document':
        unawaited(_run(_closeDocument));
      case 'clear-recent':
        vm.recent.clear();
        vm.persist();
        setState(() {});
      case 'compact':
        vm.updateAppearance(compact: !vm.compact);
      case 'files' || 'outline':
        if (!vm.sidebar) vm.toggleSidebar();
        vm.setOutline(action == 'outline');
        if (MediaQuery.sizeOf(context).width < 700) {
          _scaffold.currentState?.openDrawer();
        }
      case 'fullscreen':
        if (widget.windowIntegration) {
          unawaited(
            _run(
              () async => windowManager.setFullScreen(
                !await windowManager.isFullScreen(),
              ),
            ),
          );
        }
      case 'maximize':
        if (widget.windowIntegration) {
          unawaited(
            _run(() async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            }),
          );
        }
      case 'zoom-in' || 'zoom-out' || 'zoom-reset':
        vm.updateAppearance(
          fontSize: action == 'zoom-reset'
              ? 16
              : (vm.fontSize + (action == 'zoom-in' ? 1 : -1)).clamp(12, 22),
        );
      case 'lines':
        vm.updateAppearance(lineNumbers: !vm.lineNumbers);
      case 'watermark':
        vm.updateWatermark(preview: !vm.watermark.preview);
      case 'pairs':
        vm.updateEditorPreferences(autoPair: !vm.editingPreferences.autoPair);
      case 'word-count':
        vm.updateAppearance(wordCountVisible: !vm.wordCountVisible);
      case 'folder-refresh':
        unawaited(_run(vm.refreshFolder));
      case 'reveal-folder':
        final path = vm.folder?.path;
        final message = context.l10n.revealFolder;
        if (path != null) {
          unawaited(
            _run(() async {
              if (!await launchUrl(
                Uri.directory(path),
                mode: LaunchMode.externalApplication,
              )) {
                throw FileSystemException(message, path);
              }
            }),
          );
        }
      case 'motion':
        vm.updateAppearance(motion: !vm.motion);
      case 'website' || 'feedback':
        unawaited(
          launchUrl(
            Uri.parse(
              action == 'website'
                  ? 'https://codewf.com'
                  : 'https://github.com/dotnet9/Vex-Flutter/issues',
            ),
            mode: LaunchMode.externalApplication,
          ),
        );
      case 'mcp-audit':
        unawaited(
          showPreferences(
            context,
            vm,
            category: PreferenceCategory.mcp,
            mcpTab: 2,
          ),
        );
      case 'open':
        unawaited(_run(vm.open));
      case 'folder':
        unawaited(_run(vm.openFolder));
      case 'save':
        unawaited(
          _run(() async {
            await vm.save();
          }),
        );
      case 'save-as':
        unawaited(
          _run(() async {
            await vm.save(saveAs: true);
          }),
        );
      case 'undo':
        vm.editor.session.undo();
      case 'redo':
        vm.editor.session.redo();
      case 'copy':
        if (_focusedClipboardAction(action)) return;
        unawaited(
          Clipboard.setData(
            ClipboardData(
              text:
                  vm.editor.selection.isValid &&
                      !vm.editor.selection.isCollapsed
                  ? vm.editor.source.selection.textInside(vm.editor.source.text)
                  : vm.editor.session.text,
            ),
          ),
        );
      case 'cut':
        if (_focusedClipboardAction(action)) return;
        final editor = vm.editor, document = vm.current;
        final selection = editor.selection, source = editor.text;
        if (selection.isValid && !selection.isCollapsed) {
          unawaited(
            _run(() async {
              await Clipboard.setData(
                ClipboardData(text: selection.textInside(source)),
              );
              if (!mounted ||
                  !identical(vm.current, document) ||
                  editor.text != source ||
                  editor.selection != selection ||
                  !vm.canEditText) {
                return;
              }
              editor.replaceSelection('');
            }),
          );
        }
      case 'paste':
        if (_focusedClipboardAction(action)) return;
        final editor = vm.editor, document = vm.current;
        final selection = editor.selection, source = editor.text;
        unawaited(
          _run(() async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (!mounted ||
                !identical(vm.current, document) ||
                editor.text != source ||
                editor.selection != selection ||
                !vm.canEditText) {
              return;
            }
            if (data?.text != null) editor.replaceSelection(data!.text!);
          }),
        );
      case 'select-all':
        if (_focusedClipboardAction(action)) return;
        vm.editor.select(0, vm.editor.session.text.length);
      case 'find' || 'replace':
        vm.showFind(replace: action == 'replace');
        _findFocus.requestFocus();
      case 'layouts':
        _layoutsMenu.isOpen ? _layoutsMenu.close() : _layoutsMenu.open();
      case 'appearance':
        unawaited(showAppearance(context, vm));
      case 'typography':
        _typographyMenu.isOpen
            ? _typographyMenu.close()
            : _typographyMenu.open();
      case 'map-appearance':
        if (!vm.layout.panes.contains('map')) vm.setLayout(WorkspaceLayout.map);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapAppearanceMenu.open();
        });
      case 'summary':
        unawaited(showSummarySettings(context, vm));
      case 'settings':
        unawaited(showSettings(context, vm));
      case 'mcp':
        unawaited(
          showPreferences(context, vm, category: PreferenceCategory.mcp),
        );
      case 'about':
        unawaited(
          showAbout(
            context,
            closeWorkspace: (approve) =>
                _requestClose(beforeNativeClose: approve),
          ),
        );
      case 'thanks':
        unawaited(
          _run(() => showBuiltinDocument(context, BuiltinDocument.thanks)),
        );
      case 'changelog':
        unawaited(
          _run(() => showBuiltinDocument(context, BuiltinDocument.changelog)),
        );
      case 'guide':
        vm.startGuide();
      case 'mermaid-examples':
        vm.openMermaidExamples();
      case 'mermaid-picker':
        unawaited(_run(_insertMermaid));
      case 'sidebar':
        vm.toggleSidebar();
      case 'focus':
        vm.toggleFocus();
      case 'typewriter':
        vm.toggleTypewriter();
      case 'presentation':
        unawaited(_run(_togglePresentation));
      case 'exit':
        unawaited(_close());
      case 'export':
        unawaited(_export());
    }
  }

  bool _focusedClipboardAction(String action) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    final editable = focusContext.findAncestorStateOfType<EditableTextState>();
    // Document commands use the shared controller/history, not Flutter's local buffer.
    if (editable == null ||
        editable.widget.controller == vm.editor.source ||
        editable.context.findAncestorWidgetOfExactType<WorkspacePanes>() !=
            null) {
      return false;
    }
    final intent = switch (action) {
      'copy' => CopySelectionTextIntent.copy,
      'cut' => const CopySelectionTextIntent.cut(SelectionChangedCause.toolbar),
      'paste' => const PasteTextIntent(SelectionChangedCause.toolbar),
      _ => const SelectAllTextIntent(SelectionChangedCause.toolbar),
    };
    if (Actions.maybeFind<Intent>(editable.context, intent: intent) == null) {
      return false;
    }
    Actions.invoke(editable.context, intent);
    return true;
  }

  Future<void> _openWindow({required bool currentDocument}) async {
    if (!_desktop) return;
    vm.endGuide();
    final arguments = <String>[];
    if (currentDocument) {
      final document = vm.current;
      if (document.path == null || document.editor.session.isDirty) {
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AppDialog(
            title: context.l10n.documentWindow,
            actions: [
              AppButton(
                label: context.l10n.cancel,
                onPressed: () => Navigator.pop(context),
              ),
              AppButton(
                label: context.l10n.save,
                primary: true,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
            child: Text(context.l10n.unsavedDocuments(1)),
          ),
        );
        if (approved != true || !mounted || !vm.documents.contains(document)) {
          return;
        }
        if (!await vm.save(document: document)) return;
      }
      if (document.path == null || document.editor.session.isDirty) return;
      arguments.add(document.path!);
    }
    await Process.start(
      Platform.resolvedExecutable,
      arguments,
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> _closeDocument() async {
    vm.endGuide();
    final document = vm.current;
    final revision = document.editor.session.revision;
    var keepDraft = false;
    if (document.editor.session.isDirty) {
      final decision = await showUnsavedDialog(context, [
        document,
      ], recovery: vm.filePreferences.recovery);
      if (decision == null || !mounted || !vm.documents.contains(document)) {
        return;
      }
      if (decision == 'save' && !await vm.save(document: document)) return;
      keepDraft = decision == 'draft';
    }
    await vm.closeDocument(
      document,
      keepDraft: keepDraft,
      expectedRevision: revision,
    );
  }

  Future<void> _export() async {
    await showExportDialog(context, vm);
  }

  Future<void> _saveGuideCopy() async {
    final source = vm.editor.text;
    await vm.files.saveAs(
      '${vm.strings.quickStart}.md',
      Uint8List.fromList(utf8.encode(source)),
      dialogTitle: vm.strings.saveAs,
    );
  }

  bool _copyingForPublishing = false;

  Future<void> _copyForPublishing(PublishingPlatform platform) async {
    if (_copyingForPublishing) return;
    _copyingForPublishing = true;
    // Capture the selected document and all rendering options before awaiting.
    final source = vm.editor.text, title = vm.current.name;
    final path = vm.current.path, typography = vm.typography;
    final compact = vm.compact, markdown = vm.markdownPreferences;
    try {
      final content = await SocialCopyService().prepare(
        platform: platform,
        source: source,
        title: title,
        documentPath: path,
        typography: typography,
        compact: compact,
        markdown: markdown,
      );
      if (!mounted) return;
      await SocialCopyService.write(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.copiedForPublishing)),
        );
      }
    } finally {
      _copyingForPublishing = false;
    }
  }

  Future<void> _insertMermaid() async {
    final document = vm.current, editor = vm.editor;
    final source = editor.text, selection = editor.selection;
    final template = await showMermaidPicker(context);
    if (!mounted ||
        template == null ||
        !identical(vm.current, document) ||
        !vm.canEditText) {
      return;
    }
    if (editor.text != source) throw StateError(context.l10n.documentChanged);
    if (selection.isValid) {
      editor.select(selection.baseOffset, selection.extentOffset);
    }
    editor.insertMermaid(template.source);
  }

  Future<void> _togglePresentation() async {
    if (_changingPresentation) return;
    _changingPresentation = true;
    try {
      if (!vm.presentation) {
        _presentationPreviousFocus = FocusManager.instance.primaryFocus;
        FocusManager.instance.primaryFocus?.unfocus();
        if (widget.windowIntegration && _desktop) {
          _presentationWasFullscreen = await windowManager.isFullScreen();
          if (!_presentationWasFullscreen!) {
            await windowManager.setFullScreen(true);
          }
        }
        if (!mounted) return;
        vm.togglePresentation(outline: MediaQuery.sizeOf(context).width >= 700);
      } else {
        vm.togglePresentation();
        if (widget.windowIntegration &&
            _desktop &&
            _presentationWasFullscreen != null) {
          await windowManager.setFullScreen(_presentationWasFullscreen!);
        }
        _presentationWasFullscreen = null;
        final previous = _presentationPreviousFocus;
        if (previous?.context != null) previous!.requestFocus();
        _presentationPreviousFocus = null;
      }
    } finally {
      _changingPresentation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceViewModel>(),
        c = Theme.of(context).colorScheme;
    if (state.notice != _lastNotice) {
      _lastNotice = state.notice;
      final notice = _lastNotice;
      if (notice.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || state.notice != notice) return;
          final messenger = ScaffoldMessenger.of(_scaffold.currentContext!);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(notice),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
    }
    final workspace = LayoutBuilder(
      builder: (context, constraints) {
        // Constraints rebuild all panes; deriving the viewport must neither
        // notify Provider during layout nor overwrite the saved arrangement.
        state.windowSize = constraints.biggest;
        state.viewport = WorkspaceViewport.forWindow(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          desktop: _desktop,
        );
        _scheduleGuideStep(state);
        final phone = state.viewport == WorkspaceViewport.phone;
        final desktop = _desktop && !phone;
        final showSidebar = !phone && state.sidebar && !state.focusMode;
        final width = state.sidebarWidth.clamp(
          200.0,
          (constraints.maxWidth - 420).clamp(200.0, 560.0),
        );
        return CallbackShortcuts(
          bindings: state.presentation
              ? {}
              : {
                  ..._menuShortcuts(_menus(constraints.maxWidth)),
                  if (desktop && !_macOS)
                    for (final (key, id) in const [
                      (LogicalKeyboardKey.keyF, 'file'),
                      (LogicalKeyboardKey.keyE, 'edit'),
                      (LogicalKeyboardKey.keyP, 'paragraph'),
                      (LogicalKeyboardKey.keyO, 'format'),
                      (LogicalKeyboardKey.keyV, 'view'),
                      (LogicalKeyboardKey.keyT, 'tools'),
                      (LogicalKeyboardKey.keyH, 'help'),
                    ])
                      SingleActivator(key, alt: true): () => _openTopMenu(id),
                  if (!_macOS)
                    const SingleActivator(
                      LogicalKeyboardKey.keyZ,
                      control: true,
                      shift: true,
                    ): () =>
                        _action('redo'),
                  const SingleActivator(LogicalKeyboardKey.escape): () {
                    for (final menu in [
                      ..._topMenus.values,
                      ..._compactTopMenus.values,
                    ]) {
                      menu.close();
                    }
                    _overflowMenu.close();
                    _layoutsMenu.close();
                    _typographyMenu.close();
                    state.closeFind();
                    if (state.guiding) state.endGuide();
                  },
                },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              key: _scaffold,
              drawer: phone
                  ? Drawer(
                      width: 280,
                      child: SafeArea(
                        child: WorkspaceSidebar(
                          key: _guideSidebar,
                          vm: state,
                          onAction: _action,
                          onNavigate: () => Navigator.pop(context),
                          onOpenPath: (path) {
                            Navigator.pop(context);
                            unawaited(_run(() => state.openPath(path)));
                          },
                        ),
                      ),
                    )
                  : null,
              body: SafeArea(
                top: !desktop,
                bottom: !desktop,
                child: DropTarget(
                  onDragEntered: (_) => setState(() => _dragging = true),
                  onDragExited: (_) => setState(() => _dragging = false),
                  onDragDone: (details) {
                    setState(() => _dragging = false);
                    if (state.presentation) return;
                    for (final file in details.files) {
                      unawaited(_run(() => state.openPath(file.path)));
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Offstage(
                        offstage: state.presentation,
                        child: TickerMode(
                          enabled: !state.presentation,
                          child: Column(
                            children: [
                              if (desktop && !_macOS)
                                _titlebar(state, constraints.maxWidth),
                              _workbar(state, phone, constraints.maxWidth),
                              if (state.recoverable.isNotEmpty)
                                _banner(
                                  context.l10n.recoveryDraftCount(
                                    state.recoverable.length,
                                  ),
                                  [
                                    AppButton(
                                      label: context.l10n.restore,
                                      onPressed: () =>
                                          unawaited(_run(state.restoreDrafts)),
                                    ),
                                    AppButton(
                                      label: context.l10n.discard,
                                      onPressed: () =>
                                          unawaited(_run(state.discardDrafts)),
                                    ),
                                  ],
                                ),
                              if (state.externalChange != null)
                                _banner(context.l10n.externalChange, [
                                  AppButton(
                                    label: context.l10n.reload,
                                    onPressed: () async {
                                      if (state.editor.session.isDirty) {
                                        final yes = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AppDialog(
                                            title: context
                                                .l10n
                                                .loadExternalChanges,
                                            actions: [
                                              AppButton(
                                                label: context.l10n.cancel,
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                              ),
                                              AppButton(
                                                label: context.l10n.load,
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                              ),
                                            ],
                                            child: Text(
                                              context.l10n.loadExternalHint,
                                            ),
                                          ),
                                        );
                                        if (yes != true) return;
                                      }
                                      state.reloadExternal();
                                    },
                                  ),
                                  AppButton(
                                    label: context.l10n.saveCurrentAs,
                                    onPressed: () => _action('save-as'),
                                  ),
                                ]),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (showSidebar)
                                      SizedBox(
                                        width: width,
                                        child: WorkspaceSidebar(
                                          key: _guideSidebar,
                                          vm: state,
                                          onAction: _action,
                                          onOpenPath: (path) => unawaited(
                                            _run(() => state.openPath(path)),
                                          ),
                                        ),
                                      ),
                                    if (showSidebar)
                                      MouseRegion(
                                        cursor:
                                            SystemMouseCursors.resizeLeftRight,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onHorizontalDragUpdate: (d) =>
                                              state.resizeSidebar(
                                                width + d.delta.dx,
                                              ),
                                          onHorizontalDragEnd: (_) =>
                                              state.persist(),
                                          child: Container(
                                            width: 3,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: c.outlineVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          if (state.findVisible)
                                            _findbar(state, phone),
                                          if (state.layout.panes.any(
                                            (p) =>
                                                p == 'source' || p == 'instant',
                                          ))
                                            _formatbar(state, phone),
                                          Expanded(
                                            child: _documentSurface(
                                              state,
                                              phone,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (phone) _mobileNav(state),
                            ],
                          ),
                        ),
                      ),
                      OverlayPortal(
                        overlayLocation: OverlayChildLocation.rootOverlay,
                        controller: _guideOverlay,
                        overlayChildBuilder: (context) => Positioned.fill(
                          child: SafeArea(child: _guide(state)),
                        ),
                      ),
                      if (state.presentation)
                        Positioned.fill(
                          child: WorkspacePresentation(
                            documentPath: state.current.path,
                            controller: state.presenter!,
                            typography: state.typography,
                            fontSize: state.fontSize,
                            preferences: state.markdownPreferences,
                            onExit: () => unawaited(_run(_togglePresentation)),
                          ),
                        ),
                      if (_dragging)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: c.primary.withValues(alpha: .15),
                              child: Center(
                                child: Text(
                                  context.l10n.dropMarkdown,
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (!_macOS) return workspace;
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Vex',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: context.l10n.about,
                  onSelected: () => _action('about'),
                ),
                PlatformMenuItem(
                  label: context.l10n.settings,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.comma,
                    meta: true,
                  ),
                  onSelected: () => _action('settings'),
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: context.l10n.quitApp,
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyQ,
                    meta: true,
                  ),
                  onSelected: () => unawaited(_close()),
                ),
              ],
            ),
          ],
        ),
        for (final menu in _menus(MediaQuery.sizeOf(context).width))
          PlatformMenu(
            label: workspaceMenuLabel(menu.label),
            menus: state.presentation
                ? const []
                : workspacePlatformItems(menu.children, _action),
          ),
        PlatformMenu(
          label: context.l10n.menuWindow,
          menus: const [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
      ],
      child: workspace,
    );
  }

  Map<ShortcutActivator, VoidCallback> _menuShortcuts(
    List<WorkspaceMenuEntry> menus,
  ) {
    final shortcuts = <ShortcutActivator, VoidCallback>{};
    for (final item in menus) {
      shortcuts.addAll(_menuShortcuts(item.children));
      if (item.shortcut != null &&
          item.enabled &&
          !const ['cut', 'copy', 'paste', 'select-all'].contains(item.id)) {
        shortcuts[item.shortcut!] = () => _action(item.id);
      }
    }
    return shortcuts;
  }

  Widget _banner(String text, List<Widget> actions) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(text, style: const TextStyle(fontSize: 12)),
        ...actions,
      ],
    ),
  );
  Widget _titlebar(WorkspaceViewModel state, double width) {
    final c = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('custom-titlebar'),
      height: 33,
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          SvgPicture.asset('assets/brand/logo.svg', width: 22, height: 22),
          const SizedBox(width: 7),
          if (width >= 980)
            const Text(
              'Vex',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final menus = _menus(width);
                final (full, compact) = _measureMenus(menus);
                final available = constraints.maxWidth - 24;
                _overflowedMenus = compact > available;
                return Row(
                  children: [
                    if (_overflowedMenus)
                      MenuAnchor(
                        key: const ValueKey('titlebar-overflow-anchor'),
                        controller: _overflowMenu,
                        menuChildren: [
                          for (final menu in menus)
                            SubmenuButton(
                              key: ValueKey('compact-menu-${menu.id}'),
                              controller: _compactTopMenus.putIfAbsent(
                                menu.id,
                                MenuController.new,
                              ),
                              menuChildren: _guideMenuChildren(menu),
                              child: Text(workspaceMenuLabel(menu.label)),
                            ),
                        ],
                        builder: (context, controller, _) => AppButton(
                          key: const ValueKey('titlebar-overflow'),
                          icon: 'menu',
                          tooltip: context.l10n.menuMore,
                          onPressed: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                        ),
                      )
                    else
                      for (final menu in menus)
                        _menu(
                          menu,
                          compact: full > available,
                          key: menu.id == 'file' ? _guideFileMenu : null,
                        ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: widget.windowIntegration
                            ? (_) => windowManager.startDragging()
                            : null,
                        onDoubleTap: widget.windowIntegration
                            ? () async {
                                if (await windowManager.isMaximized()) {
                                  await windowManager.unmaximize();
                                } else {
                                  await windowManager.maximize();
                                }
                              }
                            : null,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (width >= 1280) ...[
            AppButton(
              key: const ValueKey('titlebar-theme'),
              label: switch (state.themeMode) {
                ThemeMode.light => '☀',
                ThemeMode.dark => '☾',
                ThemeMode.system => '◐',
              },
              tooltip:
                  '${context.l10n.themeMode} · ${switch (state.themeMode) {
                    ThemeMode.light => context.l10n.light,
                    ThemeMode.dark => context.l10n.dark,
                    ThemeMode.system => context.l10n.followSystem,
                  }}',
              bordered: true,
              padding: 7,
              onPressed: () => state.updateAppearance(
                mode: switch (state.themeMode) {
                  ThemeMode.light => ThemeMode.dark,
                  ThemeMode.dark => ThemeMode.system,
                  ThemeMode.system => ThemeMode.light,
                },
              ),
            ),
            for (final palette in paletteNames.entries)
              Tooltip(
                message: context.l10n.paletteName(palette.key),
                child: Semantics(
                  button: true,
                  selected: state.palette == palette.key,
                  child: InkWell(
                    onTap: () => state.updateAppearance(palette: palette.key),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 22,
                      height: 32,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: state.palette == palette.key
                                    ? Border.all(color: c.primary, width: 2)
                                    : null,
                              ),
                            ),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: paletteSchemes['${palette.key}-light']!
                                    .primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          MenuAnchor(
            menuChildren: [
              for (final language in languageNames.entries)
                MenuItemButton(
                  key: ValueKey('titlebar-language-${language.key}'),
                  leadingIcon: SizedBox(
                    width: 16,
                    child: state.language == language.key
                        ? const AppGlyph('check')
                        : null,
                  ),
                  onPressed: () =>
                      state.updateAppearance(language: language.key),
                  child: Text(language.value),
                ),
            ],
            builder: (context, controller, _) => AppButton(
              key: const ValueKey('titlebar-language'),
              label: '文ᴬ',
              tooltip: context.l10n.language,
              selected: controller.isOpen,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.windowIntegration) ...[
            AppCaptionButton(
              icon: 'min',
              tooltip: context.l10n.minimize,
              onPressed: () => windowManager.minimize(),
            ),
            AppCaptionButton(
              icon: _maximized ? 'restore' : 'max',
              tooltip: context.l10n.maximizeRestore,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
          ],
          AppCaptionButton(
            icon: 'x',
            tooltip: context.l10n.close,
            onPressed: () => unawaited(_close()),
            close: true,
          ),
        ],
      ),
    );
  }

  (double, double) _measureMenus(List<WorkspaceMenuEntry> menus) {
    final style = Theme.of(context).textTheme.labelLarge!.merge(_menuTextStyle);
    final scaler = MediaQuery.textScalerOf(context);
    final key = (style, scaler, menus.map((menu) => menu.label).join('\u0000'));
    if (_menuSizingKey == key) return _menuWidths;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: scaler,
    );
    double measure(String label) {
      painter.text = TextSpan(text: label, style: style);
      painter.layout();
      return painter.width.ceil() + 20;
    }

    var full = 0.0, compact = 0.0;
    for (final menu in menus) {
      full += measure(menu.label);
      compact += measure(workspaceMenuLabel(menu.label));
    }
    painter.dispose();
    _menuSizingKey = key;
    return _menuWidths = (full, compact);
  }

  void _openTopMenu(String id) {
    if (_overflowedMenus) {
      _overflowMenu.open();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _compactTopMenus[id]?.open();
      });
    } else {
      _topMenus[id]?.open();
    }
  }

  Widget _menu(
    WorkspaceMenuEntry menu, {
    Key? key,
    bool compact = false,
  }) => MenuAnchor(
    key: key,
    controller: _topMenus.putIfAbsent(menu.id, MenuController.new),
    menuChildren: _guideMenuChildren(menu),
    builder: (context, controller, _) => MouseRegion(
      onEnter: (_) {
        if (!controller.isOpen && _topMenus.values.any((menu) => menu.isOpen)) {
          for (final menu in _topMenus.values) {
            menu.close();
          }
          controller.open();
        }
      },
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          textStyle: _menuTextStyle,
          minimumSize: const Size(0, 28),
          fixedSize: const Size.fromHeight(28),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Text(
          compact ? workspaceMenuLabel(menu.label) : menu.label,
          maxLines: 1,
        ),
      ),
    ),
  );

  List<Widget> _menuChildren(List<WorkspaceMenuEntry> items) =>
      workspaceMenuWidgets(
        context,
        items,
        _action,
        availableSize: vm.windowSize,
      );

  List<Widget> _guideMenuChildren(WorkspaceMenuEntry menu) {
    final items = _menuChildren(menu.children);
    final selected =
        vm.guiding &&
        ((vm.guideStep == 5 && menu.id == 'file') ||
            (vm.guideStep == 6 && menu.id == 'tools'));
    return selected
        ? [
            Column(
              key: _guideCommands,
              mainAxisSize: MainAxisSize.min,
              children: items,
            ),
          ]
        : items;
  }

  Future<void> _touchMenu(double width) async {
    final action = await showWorkspaceTouchMenu(
      context,
      workspaceTouchMenus(_menus(width)),
    );
    if (!mounted || action == null) return;
    _action(action);
  }

  Widget _workbar(WorkspaceViewModel state, bool phone, double width) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: phone
          ? 56
          : width < 1100
          ? 55
          : 62,
      padding: EdgeInsets.symmetric(horizontal: phone ? 10 : 20),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${state.current.name}${state.editor.session.isDirty ? ' •' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (!phone) ...[
            _viewSwitch(state, width),
            SizedBox(width: width < 1100 ? 8 : 14),
          ],
          if (!phone)
            WorkspacePickerAnchor(
              popupKey: _guideLayoutPopup,
              vm: state,
              picker: WorkspacePicker.layout,
              controller: _layoutsMenu,
              child: AppButton(
                label: phone ? null : context.l10n.layoutDropdown,
                icon: 'columns',
                trailingIcon: phone ? null : 'chevron-down',
                tooltip: context.l10n.workspaceLayout,
                bordered: !phone,
                padding: 11,
                onPressed: () => _action('layouts'),
              ),
            ),
          if (!phone) const SizedBox(width: 14),
          if (phone)
            _workActions(state, phone, width)
          else
            Expanded(child: _workActions(state, phone, width)),
        ],
      ),
    );
  }

  Widget _workActions(WorkspaceViewModel state, bool phone, double width) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!phone && width >= 1100 && !state.guideSeen)
            Flexible(
              child: AppButton(
                label: context.l10n.quickStartBadge,
                onPressed: () => _action('guide'),
              ),
            ),
          AppButton(
            icon: 'search',
            tooltip: context.l10n.findTooltip,
            onPressed: () => _action('find'),
          ),
          const SizedBox(width: 6),
          AppButton(
            key: _guideSave,
            icon: 'save',
            label: width < 1100 ? null : context.l10n.save,
            bordered: true,
            tooltip: state.current.saveCopy
                ? context.l10n.saveCopy
                : context.l10n.saveTooltip,
            onPressed: () => _action('save'),
          ),
          if (phone || (!_desktop && width >= 700))
            KeyedSubtree(
              key: _guideFileMenu,
              child: AppButton(
                key: const ValueKey('workspace-more-menu'),
                icon: 'more',
                tooltip: context.l10n.menuMore,
                height: 40,
                onPressed: () => unawaited(_touchMenu(width)),
              ),
            ),
        ],
      );

  Widget _viewSwitch(WorkspaceViewModel state, double width) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        spacing: 2,
        children: [
          for (final item in [
            (WorkspaceLayout.instant, context.l10n.edit, 'edit'),
            (WorkspaceLayout.read, context.l10n.read, 'eye'),
            (WorkspaceLayout.map, context.l10n.map, 'map'),
          ])
            SizedBox(
              width: width < 1100 ? 72 : 86,
              child: AppButton(
                label: item.$2,
                icon: item.$3,
                selected:
                    state.layout == item.$1 ||
                    (item.$1 == WorkspaceLayout.instant &&
                        state.layout == WorkspaceLayout.source),
                onPressed: () => state.setLayout(item.$1),
                height: 28,
              ),
            ),
        ],
      ),
    );
  }

  Widget _formatbar(WorkspaceViewModel state, bool phone) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: !phone,
              child: Row(
                children: [
                  for (final item in [
                    ('bold', context.l10n.bold, 'bold'),
                    ('italic', context.l10n.italic, 'italic'),
                    ('heading', context.l10n.heading, 'heading'),
                    ('quote', context.l10n.quote, 'quote'),
                    ('list', context.l10n.unorderedList, 'list'),
                    ('ordered', context.l10n.orderedList, 'list-number'),
                    ('task', context.l10n.taskList, 'check'),
                    ('link', context.l10n.link, 'link'),
                    ('image', context.l10n.image, 'image'),
                    ('inline-code', context.l10n.inlineCode, 'inline-code'),
                    ('code', context.l10n.codeBlock, 'code-block'),
                    ('table', context.l10n.table, 'grid'),
                  ])
                    AppButton(
                      icon: item.$3,
                      tooltip: item.$2,
                      height: 28,
                      padding: 7,
                      onPressed: state.canEditText
                          ? () => _action('format:${item.$1}')
                          : null,
                    ),
                  AppButton(
                    icon: 'map',
                    tooltip: context.l10n.mermaidDiagrams,
                    onPressed: state.canEditText
                        ? () => _action('mermaid-picker')
                        : null,
                    padding: 7,
                    height: 28,
                  ),
                  AppButton(
                    icon: 'more',
                    tooltip: context.l10n.moreFormatting,
                    onPressed: state.canEditText
                        ? () => _action('format:rule')
                        : null,
                    padding: 7,
                    height: 28,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typographyPicker(WorkspaceViewModel state, {bool iconOnly = false}) =>
      // Only key the popup: reparenting an anchored menu retains its old parent.
      WorkspacePickerAnchor(
        popupKey: _guideTypographyPopup,
        vm: state,
        picker: WorkspacePicker.typography,
        controller: _typographyMenu,
        child: AppButton(
          label: iconOnly
              ? null
              : context.l10n.typographyDropdown(
                  context.l10n.typographyName(state.typography),
                ),
          icon: iconOnly ? 'heading' : null,
          trailingIcon: iconOnly ? null : 'chevron-down',
          tooltip: context.l10n.markdownTypography,
          height: 32,
          onPressed: () => _action('typography'),
        ),
      );

  Widget _findbar(WorkspaceViewModel state, bool phone) => Container(
    key: const ValueKey('editor-findbar'),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 30,
                child: TextField(
                  controller: _find,
                  focusNode: _findFocus,
                  onChanged: state.search,
                  onSubmitted: (_) => state.nextMatch(),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(hintText: context.l10n.findText),
                ),
              ),
            ),
            const SizedBox(width: 5),
            AppButton(
              label: 'Aa',
              tooltip: context.l10n.matchCase,
              selected: state.matchCase,
              onPressed: () =>
                  state.search(_find.text, matchCase: !state.matchCase),
            ),
            AppButton(
              label: '.*',
              tooltip: context.l10n.regularExpression,
              selected: state.regex,
              onPressed: () => state.search(_find.text, regex: !state.regex),
            ),
            if (!phone)
              AppButton(
                label: context.l10n.wholeWord,
                selected: state.wholeWord,
                onPressed: () =>
                    state.search(_find.text, wholeWord: !state.wholeWord),
              ),
            AppButton(
              icon: 'chevron',
              tooltip: context.l10n.nextMatch,
              onPressed: () => state.nextMatch(),
            ),
            AppButton(
              label: context.l10n.replace,
              onPressed: state.canEditText
                  ? () => state.showFind(replace: !state.replaceVisible)
                  : null,
            ),
            AppCloseButton(
              tooltip: context.l10n.closeFind,
              onPressed: state.closeFind,
            ),
          ],
        ),
        if (state.replaceVisible && state.canEditText)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: TextField(
                      controller: _replace,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: context.l10n.replaceWith,
                      ),
                    ),
                  ),
                ),
                AppButton(
                  label: context.l10n.replace,
                  onPressed: () => state.replaceCurrent(_replace.text),
                ),
                AppButton(
                  label: context.l10n.replaceAll,
                  onPressed: () => state.replaceMatches(_replace.text),
                ),
              ],
            ),
          ),
        if (_find.text.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                state.findError ??
                    context.l10n.matchCount(state.matches.length),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _documentSurface(WorkspaceViewModel state, bool phone) {
    final document = documentTheme(Theme.of(context));
    final c = document.colorScheme;
    final source = state.layout.panes.contains('source');
    return Stack(
      key: const ValueKey('document-surface'),
      fit: StackFit.expand,
      children: [
        WorkspacePanes(
          mapAppearanceController: _mapAppearanceMenu,
          mapAppearancePopupKey: _guideMapPopup,
          typographyControl: _typographyPicker(state),
          editingKey: _guideEditing,
          mapKey: _guideMap,
          mapToolbarKey: _guideMapToolbar,
          vm: state,
          onAction: _action,
          onError: _error,
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Theme(
            data: document,
            child: Material(
              color: c.surface.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(5),
              child: Row(
                children: [
                  AppButton(
                    key: const ValueKey('document-sidebar-toggle'),
                    icon: 'sidebar',
                    tooltip: context.l10n.toggleSidebar,
                    height: phone ? 44 : 32,
                    onPressed: () {
                      if (phone) {
                        _scaffold.currentState?.openDrawer();
                      } else if (state.focusMode) {
                        state.toggleFocus();
                      } else {
                        state.toggleSidebar();
                      }
                    },
                  ),
                  AppButton(
                    key: const ValueKey('document-source-toggle'),
                    icon: 'code',
                    tooltip: source
                        ? context.l10n.instantEditing
                        : context.l10n.markdownSource,
                    selected: source,
                    height: phone ? 44 : 32,
                    onPressed: () => state.setLayout(
                      state.layout.panes.contains('map') &&
                              state.layout.panes.length > 1
                          ? source
                                ? WorkspaceLayout.instantMap
                                : WorkspaceLayout.sourceMap
                          : source
                          ? WorkspaceLayout.instant
                          : WorkspaceLayout.source,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (state.wordCountVisible && !state.focusMode)
          Positioned(
            right: 16,
            bottom: state.layout.panes.last == 'map' ? 70 : 13,
            child: Container(
              key: const ValueKey('document-word-count'),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                context.l10n.wordCount(state.editor.wordCount),
                style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }

  Widget _mobileNav(WorkspaceViewModel state) => Container(
    key: _guideMobileViews,
    height: 56,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final item in [
          (WorkspaceLayout.instant, context.l10n.writing, 'edit'),
          (WorkspaceLayout.read, context.l10n.read, 'eye'),
          (WorkspaceLayout.map, context.l10n.map, 'map'),
        ])
          Expanded(
            child: AppButton(
              label: item.$2,
              icon: item.$3,
              height: 42,
              padding: 8,
              selected: state.layout == item.$1,
              onPressed: () => state.setLayout(item.$1),
            ),
          ),
      ],
    ),
  );
  Widget _guide(WorkspaceViewModel state) {
    final steps = [
      (context.l10n.guideWriteTitle, context.l10n.guideWriteBody),
      (context.l10n.guideViewsTitle, context.l10n.guideViewsBody),
      (context.l10n.guideMapTitle, context.l10n.guideMapBody),
      (context.l10n.guideArrangeTitle, context.l10n.guideArrangeBody),
      (context.l10n.guideTypographyTitle, context.l10n.guideTypographyBody),
      (context.l10n.guideFinishTitle, context.l10n.guideFinishBody),
      (context.l10n.guideShareTitle, context.l10n.guideShareBody),
    ];
    final target = switch (state.guideStep) {
      1 => _guideSidebar,
      2 => _guideMapPopup,
      3 =>
        state.viewport == WorkspaceViewport.phone
            ? _guideMobileViews
            : _guideLayoutPopup,
      4 => _guideTypographyPopup,
      5 || 6 => _guideCommands,
      _ => _guideEditing,
    };
    return WorkspaceGuide(
      target: target,
      step: state.guideStep,
      title: steps[state.guideStep].$1,
      description: steps[state.guideStep].$2,
      onClose: _endGuide,
      onStep: (step) {
        _closeGuidePanels();
        state.advanceGuide(step);
      },
    );
  }

  void _closeGuidePanels() {
    for (final menu in [..._topMenus.values, ..._compactTopMenus.values]) {
      menu.close();
    }
    _overflowMenu.close();
    _layoutsMenu.close();
    _typographyMenu.close();
    _mapAppearanceMenu.close();
    if (_guideTouchMenu) {
      _guideTouchMenu = false;
      _guideTouchGeneration++;
      final route = _guideTouchRoute;
      _guideTouchRoute = null;
      if (route != null) _dismissGuideRoute(route);
    }
    _scaffold.currentState?.closeDrawer();
  }

  void _dismissGuideRoute(ModalRoute<String> route) {
    final navigator = route.navigator;
    if (navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  void _endGuide() {
    _closeGuidePanels();
    _guideOverlay.hide();
    vm.endGuide();
  }

  void _scheduleGuideStep(WorkspaceViewModel state) {
    final step = state.guiding ? state.guideStep : null;
    final viewport = state.viewport;
    if (_preparedGuideStep == step && _preparedGuideViewport == viewport) {
      return;
    }
    _preparedGuideStep = step;
    _preparedGuideViewport = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _preparedGuideStep != step ||
          _preparedGuideViewport != viewport) {
        return;
      }
      _closeGuidePanels();
      if (step == null) {
        _guideOverlay.hide();
        return;
      }
      switch (step) {
        case 1:
          if (state.viewport == WorkspaceViewport.phone) {
            _scaffold.currentState?.openDrawer();
          }
        case 2:
          _mapAppearanceMenu.open();
        case 3:
          if (state.viewport != WorkspaceViewport.phone) _layoutsMenu.open();
        case 4:
          _typographyMenu.open();
        case 5 || 6:
          final id = step == 5 ? 'file' : 'tools';
          if (_desktop &&
              !_macOS &&
              state.viewport != WorkspaceViewport.phone) {
            _openTopMenu(id);
          } else {
            final menu = _menus(state.windowSize.width)
                .firstWhere((item) => item.id == id);
            final commands = menu.children
                .where(
                  (item) => step == 5
                      ? const ['save', 'save-as'].contains(item.id) ||
                            item.id.startsWith('export:')
                      : item.id.startsWith('publish:'),
                )
                .toList();
            _guideTouchMenu = true;
            final generation = ++_guideTouchGeneration;
            unawaited(
              showWorkspaceTouchMenu(
                context,
                commands,
                title: workspaceMenuLabel(menu.label),
                contentKey: _guideCommands,
                onRoute: (route) {
                  if (generation == _guideTouchGeneration) {
                    _guideTouchRoute = route;
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _dismissGuideRoute(route),
                    );
                  }
                },
              ).then((action) {
                if (generation == _guideTouchGeneration) {
                  _guideTouchMenu = false;
                  _guideTouchRoute = null;
                }
                if (mounted &&
                    generation == _guideTouchGeneration &&
                    action != null &&
                    state.guiding &&
                    state.guideStep == step) {
                  _action(action);
                }
              }),
            );
          }
      }
      // Put the card above the actual menu/picker, then measure its final bounds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && state.guiding && state.guideStep == step) {
          _guideOverlay.show();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }
}
