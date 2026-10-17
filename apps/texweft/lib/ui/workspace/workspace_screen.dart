import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../data/services/file_service.dart';
import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import '../core/palette_tokens.dart';
import 'insert_table_dialog.dart';
import 'mcp_settings_dialog.dart';
import 'workspace_dialogs.dart';
import 'workspace_guide.dart';
import 'workspace_panes.dart';
import 'workspace_pickers.dart';
import 'workspace_presentation.dart';
import 'workspace_sidebar.dart';
import 'workspace_view_model.dart';
import 'builtin_documents.dart';

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
  final _guideTypography = GlobalKey(), _guideFileMenu = GlobalKey();
  final _find = TextEditingController(), _replace = TextEditingController();
  final _findFocus = FocusNode();
  final _layoutsMenu = MenuController(), _typographyMenu = MenuController();
  final _topMenus = <String, MenuController>{};
  bool _dragging = false, _closing = false, _nativeCloseApproved = false;
  bool _changingPresentation = false;
  bool _maximized = false;
  bool? _presentationWasFullscreen;
  FocusNode? _presentationPreviousFocus;
  WorkspaceViewModel get vm => context.read<WorkspaceViewModel>();
  bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
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
    if (_closing) return;
    _closing = true;
    try {
      vm.endGuide();
      final dirty = vm.documents
          .where((d) => d.editor.session.isDirty)
          .toList();
      if (dirty.isNotEmpty) {
        final decision = await showDialog<String>(
          context: context,
          builder: (context) => AppDialog(
            title: context.l10n.unsavedContent,
            width: 460,
            actions: [
              AppButton(
                label: context.l10n.cancel,
                onPressed: () => Navigator.pop(context),
              ),
              AppButton(
                label: vm.filePreferences.recovery
                    ? context.l10n.keepDraftClose
                    : context.l10n.discard,
                onPressed: () => Navigator.pop(
                  context,
                  vm.filePreferences.recovery ? 'draft' : 'discard',
                ),
              ),
              AppButton(
                label: context.l10n.saveAll,
                primary: true,
                onPressed: () => Navigator.pop(context, 'save'),
              ),
            ],
            child: Text(
              context.l10n.unsavedDocuments(dirty.length),
              style: const TextStyle(fontSize: 13, height: 1.8),
            ),
          ),
        );
        if (decision == null) {
          _closing = false;
          return;
        }
        if (decision == 'save') {
          try {
            for (final doc in dirty) {
              vm.switchDocument(doc);
              if (!await vm.save()) {
                _closing = false;
                return;
              }
            }
          } catch (e) {
            _error(e);
            _closing = false;
            return;
          }
        }
      }
      await vm.finishPendingSaves();
      await vm.flushRecovery(throwOnError: true);
      if (widget.windowIntegration && _desktop) {
        // Let the native window process WM_CLOSE before its message loop exits.
        // On Windows destroy() only posts WM_QUIT, leaving a live HWND while the
        // Flutter engine and COM plugins are being torn down.
        _nativeCloseApproved = true;
        await windowManager.setPreventClose(false);
        await windowManager.close();
      } else if (Platform.isAndroid) {
        await SystemNavigator.pop();
      }
    } catch (error) {
      _nativeCloseApproved = false;
      if (widget.windowIntegration && _desktop) {
        await windowManager.setPreventClose(true);
      }
      _error(error);
    } finally {
      _closing = false;
    }
  }

  void _format(String command) {
    final e = vm.editor;
    if (command.startsWith('heading-')) {
      e.linePrefix('${'#' * int.parse(command.substring(8))} ');
      return;
    }
    switch (command) {
      case 'bold':
        e.surround('**');
      case 'italic':
        e.surround('*');
      case 'strike':
        e.surround('~~');
      case 'heading':
        e.linePrefix('## ');
      case 'quote':
        e.linePrefix('> ');
      case 'list':
        e.linePrefix('- ');
      case 'ordered':
        e.linePrefix('1. ');
      case 'task':
        e.linePrefix('- [ ] ');
      case 'link':
        e.surround('[', '](https://)');
      case 'image':
        e.replaceSelection(context.l10n.imageMarkdown);
      case 'inline-code':
        e.surround('`');
      case 'code':
        e.surround('```\n', '\n```');
      case 'table':
        unawaited(_run(_insertTable));
      case 'rule':
        e.replaceSelection('\n\n---\n\n');
      case 'paragraph':
        e.replaceSelection('\n\n');
    }
  }

  Future<void> _insertTable() async {
    final document = vm.current, editor = vm.editor;
    final source = editor.text, selection = editor.selection;
    final dimensions = await showInsertTableDialog(context);
    if (!mounted || dimensions == null || !vm.documents.contains(document)) {
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
    if (action.startsWith('open-path:')) {
      unawaited(_run(() => vm.openPath(action.substring(10))));
      return;
    }
    if (action.startsWith('format:')) {
      _format(action.substring(7));
      return;
    }
    switch (action) {
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
          showDialog<void>(
            context: context,
            builder: (context) => AppDialog(
              title: context.l10n.mcpAudit,
              width: 620,
              child: ListenableBuilder(
                listenable: vm.mcp,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: vm.mcp.audit.isEmpty
                      ? [Text(context.l10n.mcpAuditEmpty)]
                      : [
                          for (final item in vm.mcp.audit)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: SelectableText(
                                '${item['time']}\n${item['tool']} · ${item['result']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                            ),
                        ],
                ),
              ),
            ),
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
        final selection = vm.editor.selection;
        if (selection.isValid && !selection.isCollapsed) {
          unawaited(
            Clipboard.setData(
              ClipboardData(text: selection.textInside(vm.editor.source.text)),
            ),
          );
          vm.editor.replaceSelection('');
        }
      case 'paste':
        unawaited(
          _run(() async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data != null) vm.editor.replaceSelection(data.text ?? '');
          }),
        );
      case 'select-all':
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
      case 'summary':
        unawaited(showSummarySettings(context, vm));
      case 'settings':
        unawaited(showSettings(context, vm));
      case 'mcp':
        unawaited(showMcpSettings(context, vm.mcp));
      case 'about':
        unawaited(showAbout(context));
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

  Future<void> _closeDocument() async {
    vm.endGuide();
    var keepDraft = false;
    if (vm.editor.session.isDirty) {
      final decision = await showDialog<String>(
        context: context,
        builder: (context) => AppDialog(
          title: context.l10n.unsavedContent,
          width: 520,
          actions: [
            AppButton(
              label: context.l10n.cancel,
              onPressed: () => Navigator.pop(context),
            ),
            AppButton(
              label: vm.filePreferences.recovery
                  ? context.l10n.keepDraftClose
                  : context.l10n.discard,
              onPressed: () => Navigator.pop(
                context,
                vm.filePreferences.recovery ? 'draft' : 'discard',
              ),
            ),
            AppButton(
              label: context.l10n.save,
              primary: true,
              onPressed: () => Navigator.pop(context, 'save'),
            ),
          ],
          child: Text(
            vm.current.name,
            style: const TextStyle(fontSize: 14, height: 1.8),
          ),
        ),
      );
      if (decision == null) return;
      if (decision == 'save' && !await vm.save()) return;
      keepDraft = decision == 'draft';
    }
    await vm.closeCurrent(keepDraft: keepDraft);
  }

  Future<void> _export() async {
    await showExportDialog(context, vm);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 700;
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
                  const SingleActivator(LogicalKeyboardKey.f5): () =>
                      _action('presentation'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyN,
                    control: true,
                  ): () =>
                      _action('new'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyO,
                    control: true,
                  ): () =>
                      _action('open'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    control: true,
                  ): () =>
                      _action('save'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    control: true,
                    shift: true,
                  ): () =>
                      _action('save-as'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyF,
                    control: true,
                  ): () =>
                      _action('find'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyH,
                    control: true,
                  ): () =>
                      _action('replace'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    control: true,
                  ): () =>
                      _action('undo'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyY,
                    control: true,
                  ): () =>
                      _action('redo'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    control: true,
                    shift: true,
                  ): () =>
                      _action('redo'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyB,
                    control: true,
                  ): () =>
                      _action('format:bold'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyI,
                    control: true,
                  ): () =>
                      _action('format:italic'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    meta: true,
                  ): () =>
                      _action('save'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyO,
                    meta: true,
                  ): () =>
                      _action('open'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyF,
                    meta: true,
                  ): () =>
                      _action('find'),
                  const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                  ): () =>
                      _action('undo'),
                  const SingleActivator(LogicalKeyboardKey.escape): () {
                    for (final menu in _topMenus.values) {
                      menu.close();
                    }
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
                          vm: state,
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
                              if (desktop)
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
                                      onPressed: state.restoreDrafts,
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
                                          vm: state,
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
                                            child: WorkspacePanes(
                                              editingKey: _guideEditing,
                                              mapKey: _guideMap,
                                              mapToolbarKey: _guideMapToolbar,
                                              vm: state,
                                              onAction: _action,
                                              onError: _error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!phone)
                                _statusbar(state, constraints.maxWidth),
                              if (phone) _mobileNav(state),
                            ],
                          ),
                        ),
                      ),
                      if (state.guiding) Positioned.fill(child: _guide(state)),
                      if (state.presentation)
                        Positioned.fill(
                          child: WorkspacePresentation(
                            documentPath: state.current.path,
                            controller: state.presenter!,
                            typography: state.typography,
                            fontSize: state.fontSize,
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
              'Texweft',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
              ),
            ),
          const SizedBox(width: 14),
          _menu(context.l10n.menuFile, [
            (context.l10n.newDocument, 'new', 'Ctrl+N'),
            ('', '-', ''),
            (context.l10n.open, 'open', 'Ctrl+O'),
            (context.l10n.openFolder, 'folder', ''),
            (context.l10n.openRecent, '@recent', ''),
            ('', '-', ''),
            (context.l10n.save, 'save', 'Ctrl+S'),
            (context.l10n.saveAs, 'save-as', 'Ctrl+Shift+S'),
            (context.l10n.saveAllDocuments, 'save-all', ''),
            (context.l10n.exportShareMenu, '@export', ''),
            (context.l10n.printPreview, 'export:print', 'Ctrl+Shift+P'),
            ('', '-', ''),
            (context.l10n.closeDocument, 'close-document', 'Ctrl+W'),
            (context.l10n.exit, 'exit', ''),
          ], key: _guideFileMenu),
          _menu(context.l10n.menuEdit, [
            (context.l10n.undo, 'undo', 'Ctrl+Z'),
            (context.l10n.redo, 'redo', 'Ctrl+Y'),
            ('', '-', ''),
            (context.l10n.cut, 'cut', 'Ctrl+X'),
            (context.l10n.copy, 'copy', 'Ctrl+C'),
            (context.l10n.paste, 'paste', 'Ctrl+V'),
            (context.l10n.selectAll, 'select-all', 'Ctrl+A'),
            ('', '-', ''),
            (context.l10n.find, 'find', 'Ctrl+F'),
            (context.l10n.replace, 'replace', 'Ctrl+H'),
          ]),
          _menu(context.l10n.menuInsert, [
            (context.l10n.newParagraph, 'format:paragraph', ''),
            for (var level = 1; level <= 6; level++)
              ('${context.l10n.heading} $level', 'format:heading-$level', ''),
            ('', '-', ''),
            (context.l10n.unorderedList, 'format:list', ''),
            (context.l10n.orderedList, 'format:ordered', ''),
            (context.l10n.taskList, 'format:task', ''),
            (context.l10n.quote, 'format:quote', ''),
            ('', '-', ''),
            (context.l10n.table, 'format:table', ''),
            (context.l10n.codeBlock, 'format:code', ''),
            (context.l10n.horizontalRule, 'format:rule', ''),
            (context.l10n.link, 'format:link', ''),
            (context.l10n.image, 'format:image', ''),
            ('', '-', ''),
            (context.l10n.bold, 'format:bold', 'Ctrl+B'),
            (context.l10n.italic, 'format:italic', 'Ctrl+I'),
            (context.l10n.strike, 'format:strike', ''),
            (context.l10n.inlineCode, 'format:inline-code', ''),
          ]),
          _menu(context.l10n.menuView, [
            (context.l10n.workspaceLayoutMenu, '@layouts', ''),
            (context.l10n.menuNavigation, '@navigation', ''),
            (context.l10n.sourceLineNumbers, 'lines', ''),
            ('', '-', ''),
            (context.l10n.focusMode, 'focus', 'F8'),
            (context.l10n.typewriterMode, 'typewriter', ''),
            (context.l10n.presentationMode, 'presentation', 'F5'),
            ('', '-', ''),
            (context.l10n.appearanceMenu, '@appearance', ''),
            (context.l10n.markdownTypography, '@typography', ''),
            ('', '-', ''),
            (context.l10n.menuWindow, '@window', ''),
            (context.l10n.zoomIn, 'zoom-in', ''),
            (context.l10n.zoomOut, 'zoom-out', ''),
            (context.l10n.actualSize, 'zoom-reset', ''),
          ]),
          _menu(context.l10n.menuTools, [
            (context.l10n.summarySettings, 'summary', ''),
            (context.l10n.settings, 'settings', ''),
            ('', '-', ''),
            (context.l10n.mcpSettings, 'mcp', ''),
            (context.l10n.mcpAudit, 'mcp-audit', ''),
          ]),
          _menu(context.l10n.menuHelp, [
            (context.l10n.quickStart, 'guide', ''),
            ('', '-', ''),
            (context.l10n.officialWebsite, 'website', ''),
            (context.l10n.feedback, 'feedback', ''),
            (context.l10n.builtinThanks, 'thanks', ''),
            (context.l10n.changelog, 'changelog', ''),
            (context.l10n.about, 'about', ''),
          ]),
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

  Widget _menu(
    String label,
    List<(String, String, String)> items, {
    Key? key,
  }) => MenuAnchor(
    key: key,
    controller: _topMenus.putIfAbsent(label, MenuController.new),
    menuChildren: _menuChildren(items),
    builder: (context, controller, _) => TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        textStyle: const TextStyle(fontSize: 14, height: 1.4),
        minimumSize: const Size(0, 28),
        fixedSize: const Size.fromHeight(28),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      child: Text(label, maxLines: 1),
    ),
  );
  List<Widget> _menuChildren(List<(String, String, String)> items) => [
    for (final item in items)
      if (item.$2 == '-')
        const Divider(height: 13, indent: 8, endIndent: 8)
      else if (item.$2.startsWith('@'))
        SubmenuButton(
          leadingIcon: const SizedBox(width: 16),
          menuChildren: _submenu(item.$2),
          child: Text(item.$1),
        )
      else
        MenuItemButton(
          leadingIcon: SizedBox(
            width: 16,
            child: _checked(item.$2) ? const AppGlyph('check') : null,
          ),
          onPressed: () => _action(item.$2),
          trailingIcon: SizedBox(
            width: 104,
            child: Text(
              item.$3,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          child: Text(item.$1),
        ),
  ];
  bool _checked(String action) => switch (action) {
    'lines' => vm.lineNumbers,
    'sidebar' => vm.sidebar,
    'compact' => vm.compact,
    'focus' => vm.focusMode,
    'typewriter' => vm.typewriter,
    _ =>
      action == 'layout:${vm.layout.name}' ||
          action == 'theme:${vm.themeMode.name}' ||
          action == 'palette:${vm.palette}' ||
          action == 'typography:${vm.typography.name}',
  };
  List<Widget> _submenu(String name) {
    final l = context.l10n;
    if (name == '@recent') {
      return [
        if (vm.recent.isEmpty) MenuItemButton(child: Text(l.noRecent)),
        for (final path in vm.recent)
          MenuItemButton(
            onPressed: () => _action('open-path:$path'),
            child: SizedBox(
              width: 320,
              child: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        if (vm.recent.isNotEmpty) ...[
          const Divider(),
          MenuItemButton(
            onPressed: () => _action('clear-recent'),
            child: Text(l.clearRecent),
          ),
        ],
      ];
    }
    return _menuChildren(switch (name) {
      '@export' => [
        ('HTML', 'export:html', ''),
        ('PDF', 'export:pdf', ''),
        ('Word (.docx)', 'export:docx', ''),
        (l.mindMapPng, 'export:png', ''),
      ],
      '@layouts' => [
        for (final layout in WorkspaceLayout.values)
          (l.layoutName(layout), 'layout:${layout.name}', ''),
      ],
      '@navigation' => [
        (l.toggleSidebar, 'sidebar', ''),
        (l.files, 'files', ''),
        (l.outline, 'outline', ''),
      ],
      '@appearance' => [
        (l.followSystem, 'theme:system', ''),
        (l.light, 'theme:light', ''),
        (l.dark, 'theme:dark', ''),
        ('', '-', ''),
        for (final palette in paletteNames.keys)
          (l.paletteName(palette), 'palette:$palette', ''),
      ],
      '@typography' => [
        for (final type in MarkdownTypography.values)
          (l.typographyName(type), 'typography:${type.name}', ''),
        ('', '-', ''),
        (l.compactSpacing, 'compact', ''),
      ],
      '@window' => [
        (l.fullscreen, 'fullscreen', 'F11'),
        (l.maximizeRestore, 'maximize', ''),
      ],
      _ => <(String, String, String)>[],
    });
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
          AppButton(
            icon: 'sidebar',
            height: 30,
            selected: state.sidebar,
            tooltip: context.l10n.filesOutline,
            onPressed: () {
              if (phone) {
                _scaffold.currentState?.openDrawer();
              } else {
                state.toggleSidebar();
              }
            },
          ),
          const SizedBox(width: 12),
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
          WorkspacePickerAnchor(
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
          if (!state.layout.panes.any((p) => p == 'source' || p == 'instant'))
            Flexible(child: _typographyPicker(state, iconOnly: phone)),
          AppButton(
            icon: 'search',
            tooltip: context.l10n.findTooltip,
            onPressed: () => _action('find'),
          ),
          const SizedBox(width: 6),
          AppButton(
            icon: 'save',
            label: phone ? null : context.l10n.save,
            bordered: true,
            tooltip: context.l10n.saveTooltip,
            onPressed: () => _action('save'),
          ),
          if (phone)
            _menu('•••', [
              (context.l10n.newAction, 'new', ''),
              (context.l10n.open, 'open', ''),
              (context.l10n.exportShare, 'export', ''),
              (context.l10n.appearance, 'appearance', ''),
              (context.l10n.layout, 'layouts', ''),
              (context.l10n.settings, 'settings', ''),
              (context.l10n.quickStart, 'guide', ''),
              (context.l10n.about, 'about', ''),
            ]),
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
          if (!phone) ...[
            AppButton(
              label: context.l10n.instantRendering,
              selected: state.layout.panes.contains('instant'),
              height: 26,
              onPressed: () => state.setLayout(
                state.layout.panes.contains('map')
                    ? WorkspaceLayout.instantMap
                    : WorkspaceLayout.instant,
              ),
            ),
            AppButton(
              label: context.l10n.source,
              selected: state.layout.panes.contains('source'),
              height: 26,
              onPressed: () => state.setLayout(
                state.layout.panes.contains('map')
                    ? WorkspaceLayout.sourceMap
                    : WorkspaceLayout.source,
              ),
            ),
            const SizedBox(width: 10),
          ],
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
                      onPressed: () => _action('format:${item.$1}'),
                    ),
                  AppButton(
                    icon: 'more',
                    tooltip: context.l10n.moreFormatting,
                    onPressed: () => _action('format:rule'),
                    padding: 7,
                    height: 28,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _typographyPicker(state),
        ],
      ),
    );
  }

  Widget _typographyPicker(WorkspaceViewModel state, {bool iconOnly = false}) =>
      WorkspacePickerAnchor(
        key: _guideTypography,
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
              onPressed: () => state.showFind(replace: !state.replaceVisible),
            ),
            AppCloseButton(
              tooltip: context.l10n.closeFind,
              onPressed: state.closeFind,
            ),
          ],
        ),
        if (state.replaceVisible)
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
  Widget _statusbar(WorkspaceViewModel state, double width) {
    final c = Theme.of(context).colorScheme;
    final position = state.editor.document.position(
      state.editor.selection.isValid ? state.editor.selection.extentOffset : 0,
    );
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border(top: BorderSide(color: c.outlineVariant)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant),
        child: Row(
          children: [
            AppGlyph(
              state.editor.session.isDirty ? 'edit' : 'check',
              size: 12,
              color: c.primary,
            ),
            const SizedBox(width: 6),
            Text(
              state.editor.session.isDirty
                  ? context.l10n.unsaved
                  : context.l10n.unmodified,
            ),
            const SizedBox(width: 16),
            Text(
              context.l10n.layoutName(state.layout),
              style: TextStyle(color: c.primary),
            ),
            if (state.status.isNotEmpty && width > 1200)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    state.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else
              const Spacer(),
            Text(context.l10n.cursorPosition(position.line, position.column)),
            const SizedBox(width: 16),
            Text(
              context.l10n.characterCount(
                state.editor.session.text.characters.length,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'UTF-8 · ${state.editor.document.newline == '\r\n' ? 'CRLF' : 'LF'}',
            ),
            const SizedBox(width: 10),
            AppButton(
              icon: 'palette',
              tooltip: context.l10n.appearance,
              height: 25,
              padding: 2,
              onPressed: () => _action('appearance'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileNav(WorkspaceViewModel state) => Container(
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
          AppButton(
            label: item.$2,
            icon: item.$3,
            height: 42,
            padding: 20,
            selected: state.layout == item.$1,
            onPressed: () => state.setLayout(item.$1),
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
    ];
    final target = switch (state.guideStep) {
      2 => _guideMap,
      3 => _guideMapToolbar,
      4 => _guideTypography,
      5 => _guideFileMenu,
      _ => _guideEditing,
    };
    return WorkspaceGuide(
      target: target,
      step: state.guideStep,
      title: steps[state.guideStep].$1,
      description: steps[state.guideStep].$2,
      onClose: state.endGuide,
      onStep: state.advanceGuide,
    );
  }
}
