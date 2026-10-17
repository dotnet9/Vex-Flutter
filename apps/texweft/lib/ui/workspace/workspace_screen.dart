import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../data/services/file_service.dart';
import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import '../core/palette_tokens.dart';
import 'insert_table_dialog.dart';
import 'workspace_dialogs.dart';
import 'workspace_panes.dart';
import 'workspace_pickers.dart';
import 'workspace_sidebar.dart';
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
  final _find = TextEditingController(), _replace = TextEditingController();
  final _findFocus = FocusNode();
  final _layoutsMenu = MenuController(), _typographyMenu = MenuController();
  bool _dragging = false, _closing = false, _nativeCloseApproved = false;
  WorkspaceViewModel get vm => context.read<WorkspaceViewModel>();
  bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.windowIntegration && _desktop) windowManager.addListener(this);
  }

  @override
  void dispose() {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final title = context.l10n.appTitle;
    if (widget.windowIntegration && _desktop) {
      unawaited(windowManager.setTitle(title));
    }
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
                label: context.l10n.keepDraftClose,
                onPressed: () => Navigator.pop(context, 'draft'),
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
    if (action.startsWith('format:')) {
      _format(action.substring(7));
      return;
    }
    switch (action) {
      case 'new':
        vm.newDocument();
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
      case 'about':
        unawaited(showAbout(context));
      case 'guide':
        vm.startGuide();
      case 'sidebar':
        vm.toggleSidebar();
      case 'focus':
        vm.toggleFocus();
      case 'presentation':
        vm.togglePresentation();
      case 'exit':
        unawaited(_close());
      case 'export':
        unawaited(_export());
    }
  }

  Future<void> _export() async {
    await showExportDialog(context, vm);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceViewModel>(),
        c = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 700;
        final desktop = _desktop && !phone;
        final showSidebar =
            !phone && state.sidebar && !state.focusMode && !state.presentation;
        final width = state.sidebarWidth.clamp(
          200.0,
          (constraints.maxWidth - 420).clamp(200.0, 560.0),
        );
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
                _action('new'),
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
                _action('open'),
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
                _action('save'),
            const SingleActivator(
              LogicalKeyboardKey.keyS,
              control: true,
              shift: true,
            ): () =>
                _action('save-as'),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                _action('find'),
            const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
                _action('replace'),
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
                _action('undo'),
            const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
                _action('redo'),
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              control: true,
              shift: true,
            ): () =>
                _action('redo'),
            const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
                _action('format:bold'),
            const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
                _action('format:italic'),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
                _action('save'),
            const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () =>
                _action('open'),
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
                _action('find'),
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () =>
                _action('undo'),
            const SingleActivator(LogicalKeyboardKey.escape): () {
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
                          onFolder: () => _action('folder'),
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
                    for (final file in details.files) {
                      unawaited(_run(() => state.openPath(file.path)));
                    }
                  },
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          if (desktop && !state.presentation)
                            _titlebar(state, constraints.maxWidth),
                          if (!state.presentation)
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
                                        title: context.l10n.loadExternalChanges,
                                        actions: [
                                          AppButton(
                                            label: context.l10n.cancel,
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                          ),
                                          AppButton(
                                            label: context.l10n.load,
                                            onPressed: () =>
                                                Navigator.pop(context, true),
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
                          if (state.findVisible) _findbar(state, phone),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showSidebar)
                                  SizedBox(
                                    width: width,
                                    child: WorkspaceSidebar(
                                      vm: state,
                                      onOpenPath: (path) => unawaited(
                                        _run(() => state.openPath(path)),
                                      ),
                                      onFolder: () => _action('folder'),
                                    ),
                                  ),
                                if (showSidebar)
                                  MouseRegion(
                                    cursor: SystemMouseCursors.resizeLeftRight,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragUpdate: (d) => state
                                          .resizeSidebar(width + d.delta.dx),
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
                                      if (!state.presentation &&
                                          state.layout.panes.any(
                                            (p) =>
                                                p == 'source' || p == 'instant',
                                          ))
                                        _formatbar(state, phone),
                                      Expanded(
                                        child: WorkspacePanes(
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
                          if (state.guiding) _guide(state),
                          if (!phone && !state.presentation)
                            _statusbar(state, constraints.maxWidth),
                          if (phone && !state.presentation) _mobileNav(state),
                        ],
                      ),
                      if (state.presentation)
                        Positioned(
                          right: 16,
                          top: 16,
                          child: AppButton(
                            label: context.l10n.exitPresentation,
                            icon: 'x',
                            bordered: true,
                            onPressed: state.togglePresentation,
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
        Text(text, style: const TextStyle(fontSize: 11)),
        ...actions,
      ],
    ),
  );
  Widget _titlebar(WorkspaceViewModel state, double width) {
    final c = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: c.outlineVariant)),
      ),
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          SvgPicture.asset('assets/brand/logo.svg', width: 22, height: 22),
          const SizedBox(width: 7),
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
            (context.l10n.open, 'open', 'Ctrl+O'),
            (context.l10n.openFolder, 'folder', ''),
            (context.l10n.save, 'save', 'Ctrl+S'),
            (context.l10n.saveAs, 'save-as', 'Ctrl+Shift+S'),
            (context.l10n.exportShareMenu, 'export', ''),
            (context.l10n.exit, 'exit', ''),
          ]),
          _menu(context.l10n.menuEdit, [
            (context.l10n.undo, 'undo', 'Ctrl+Z'),
            (context.l10n.redo, 'redo', 'Ctrl+Y'),
            (context.l10n.cut, 'cut', 'Ctrl+X'),
            (context.l10n.copy, 'copy', 'Ctrl+C'),
            (context.l10n.paste, 'paste', 'Ctrl+V'),
            (context.l10n.selectAll, 'select-all', 'Ctrl+A'),
            (context.l10n.find, 'find', 'Ctrl+F'),
            (context.l10n.replace, 'replace', 'Ctrl+H'),
          ]),
          _menu(context.l10n.menuInsert, [
            (context.l10n.heading, 'format:heading', ''),
            (context.l10n.quote, 'format:quote', ''),
            (context.l10n.link, 'format:link', ''),
            (context.l10n.image, 'format:image', ''),
            (context.l10n.codeBlock, 'format:code', ''),
            (context.l10n.table, 'format:table', ''),
            (context.l10n.horizontalRule, 'format:rule', ''),
          ]),
          _menu(context.l10n.menuView, [
            (context.l10n.workspaceLayoutMenu, 'layouts', ''),
            (context.l10n.toggleSidebar, 'sidebar', ''),
            (context.l10n.focusMode, 'focus', ''),
            (context.l10n.presentationMode, 'presentation', ''),
            (context.l10n.appearanceMenu, 'appearance', ''),
          ]),
          _menu(context.l10n.menuTools, [
            (context.l10n.summarySettings, 'summary', ''),
            (context.l10n.exportShare, 'export', ''),
            (context.l10n.settings, 'settings', ''),
          ]),
          _menu(context.l10n.menuHelp, [
            (context.l10n.quickStart, 'guide', ''),
            (context.l10n.aboutUpdates, 'about', ''),
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
          if (width >= 1100) ...[
            AppButton(
              label: Theme.of(context).brightness == Brightness.light
                  ? '☀'
                  : '☾',
              tooltip: context.l10n.toggleTheme,
              padding: 7,
              onPressed: () => state.updateAppearance(
                mode: Theme.of(context).brightness == Brightness.light
                    ? ThemeMode.dark
                    : ThemeMode.light,
              ),
            ),
            for (final palette in paletteNames.entries)
              Tooltip(
                message: context.l10n.paletteName(palette.key),
                child: InkWell(
                  onTap: () => state.updateAppearance(palette: palette.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: paletteSchemes['${palette.key}-light']!.primary,
                        border: state.palette == palette.key
                            ? Border.all(color: c.primary, width: 2)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(width: 8),
          if (widget.windowIntegration) ...[
            AppButton(
              icon: 'min',
              tooltip: context.l10n.minimize,
              onPressed: () => windowManager.minimize(),
              height: 39,
              padding: 14,
            ),
            AppButton(
              icon: 'max',
              tooltip: context.l10n.maximizeRestore,
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              height: 39,
              padding: 14,
            ),
          ],
          AppButton(
            icon: 'x',
            tooltip: context.l10n.close,
            onPressed: () => unawaited(_close()),
            height: 39,
            padding: 14,
          ),
        ],
      ),
    );
  }

  Widget _menu(String label, List<(String, String, String)> items) =>
      MenuAnchor(
        menuChildren: [
          for (final item in items)
            MenuItemButton(
              onPressed: () => _action(item.$2),
              trailingIcon: item.$3.isEmpty
                  ? null
                  : Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
              child: Text(item.$1),
            ),
        ],
        builder: (context, controller, _) => AppButton(
          label: label,
          padding: 8,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        ),
      );
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
            _viewSwitch(state),
            const SizedBox(width: 14),
            const Spacer(),
            if (width >= 1100)
              AppButton(
                label: context.l10n.quickStartBadge,
                onPressed: () => _action('guide'),
              ),
          ],
          WorkspacePickerAnchor(
            vm: state,
            picker: WorkspacePicker.layout,
            controller: _layoutsMenu,
            child: AppButton(
              label: phone ? null : context.l10n.layoutDropdown,
              icon: 'columns',
              tooltip: context.l10n.workspaceLayout,
              bordered: !phone,
              onPressed: () => _action('layouts'),
            ),
          ),
          if (!state.layout.panes.any((p) => p == 'source' || p == 'instant'))
            _typographyPicker(state, iconOnly: phone),
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
      ),
    );
  }

  Widget _viewSwitch(WorkspaceViewModel state) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final item in [
            (WorkspaceLayout.instant, context.l10n.edit, 'edit'),
            (WorkspaceLayout.read, context.l10n.read, 'eye'),
            (WorkspaceLayout.map, context.l10n.map, 'map'),
          ])
            SizedBox(
              width: 80,
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
          tooltip: context.l10n.markdownTypography,
          height: 28,
          onPressed: () => _action('typography'),
        ),
      );

  Widget _findbar(WorkspaceViewModel state, bool phone) => Container(
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
                  style: const TextStyle(fontSize: 11),
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
            AppButton(
              icon: 'x',
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
                      style: const TextStyle(fontSize: 11),
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
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Flex(
        direction: narrow ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: narrow
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Flexible(
            fit: narrow ? FlexFit.loose : FlexFit.tight,
            flex: narrow ? 0 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.guideStep + 1}/6  ${steps[state.guideStep].$1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  steps[state.guideStep].$2,
                  style: const TextStyle(fontSize: 11, height: 1.7),
                ),
              ],
            ),
          ),
          SizedBox(width: narrow ? 0 : 10, height: narrow ? 10 : 0),
          Wrap(
            spacing: 6,
            children: [
              AppButton(
                label: context.l10n.endGuide,
                onPressed: state.endGuide,
              ),
              if (state.guideStep > 0)
                AppButton(
                  label: context.l10n.previous,
                  onPressed: () => state.advanceGuide(state.guideStep - 1),
                ),
              AppButton(
                label: state.guideStep == 5
                    ? context.l10n.done
                    : context.l10n.next,
                primary: true,
                onPressed: () {
                  if (state.guideStep == 5) {
                    state.endGuide();
                  } else {
                    state.advanceGuide(state.guideStep + 1);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
