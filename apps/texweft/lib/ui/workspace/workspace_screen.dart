import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../data/services/file_service.dart';
import '../../domain/file_preferences.dart';
import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
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
  final _guideSave = GlobalKey();
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
      case 'statusbar':
        vm.updateAppearance(statusbar: !vm.statusbar);
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
                  editor.selection != selection) {
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
                editor.selection != selection) {
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
      case 'summary':
        unawaited(showSummarySettings(context, vm));
      case 'settings':
        unawaited(showSettings(context, vm));
      case 'mcp':
        unawaited(
          showPreferences(context, vm, category: PreferenceCategory.mcp),
        );
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

  Future<void> _insertMermaid() async {
    final document = vm.current, editor = vm.editor;
    final source = editor.text, selection = editor.selection;
    final template = await showMermaidPicker(context);
    if (!mounted ||
        template == null ||
        (!identical(vm.current, document) &&
            !vm.documents.contains(document))) {
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
    final workspace = LayoutBuilder(
      builder: (context, constraints) {
        // Constraints rebuild all panes; deriving the viewport must neither
        // notify Provider during layout nor overwrite the saved arrangement.
        state.viewport = WorkspaceViewport.forWindow(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          desktop: _desktop,
        );
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
                      SingleActivator(key, alt: true): () =>
                          _topMenus[id]?.open(),
                  if (!_macOS)
                    const SingleActivator(
                      LogicalKeyboardKey.keyZ,
                      control: true,
                      shift: true,
                    ): () =>
                        _action('redo'),
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
                              if (!phone && state.statusbar)
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
          for (final menu in _menus(width))
            _menu(menu, key: menu.id == 'file' ? _guideFileMenu : null),
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

  Widget _menu(WorkspaceMenuEntry menu, {Key? key}) => MenuAnchor(
    key: key,
    controller: _topMenus.putIfAbsent(menu.id, MenuController.new),
    menuChildren: _menuChildren(menu.children),
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
          textStyle: const TextStyle(fontSize: 14, height: 1.4),
          minimumSize: const Size(0, 28),
          fixedSize: const Size.fromHeight(28),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Text(menu.label, maxLines: 1),
      ),
    ),
  );

  List<Widget> _menuChildren(List<WorkspaceMenuEntry> items) =>
      workspaceMenuWidgets(context, items, _action);

  Future<void> _touchMenu(double width) async {
    final action = await showWorkspaceTouchMenu(context, _menus(width));
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
            Flexible(child: _typographyPicker(state, iconOnly: width < 1100)),
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
            tooltip: context.l10n.saveTooltip,
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
                    icon: 'map',
                    tooltip: context.l10n.mermaidDiagrams,
                    onPressed: () => _action('mermaid-picker'),
                    padding: 7,
                    height: 28,
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
        style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
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
            if (width > 1100) ...[
              const SizedBox(width: 16),
              Text(
                context.l10n.layoutName(state.layout),
                style: TextStyle(color: c.primary),
              ),
            ],
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
            if (width > 900) ...[
              const SizedBox(width: 16),
              Text(
                context.l10n.characterCount(
                  state.editor.session.text.characters.length,
                ),
              ),
            ],
            const SizedBox(width: 16),
            Text(
              '${switch (state.current.format.encoding) {
                DocumentEncoding.utf8 => 'UTF-8',
                DocumentEncoding.utf8Bom => 'UTF-8 BOM',
                DocumentEncoding.gb18030 => 'GB18030',
              }} · ${state.current.format.newline == DocumentNewline.crlf || (state.current.format.newline == DocumentNewline.system && Platform.isWindows) ? 'CRLF' : 'LF'}',
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
    ];
    final target = switch (state.guideStep) {
      2 => _guideMap,
      3 => _guideMapToolbar,
      4 => _guideTypography,
      5 =>
        _macOS && state.viewport != WorkspaceViewport.phone
            ? _guideSave
            : _guideFileMenu,
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
