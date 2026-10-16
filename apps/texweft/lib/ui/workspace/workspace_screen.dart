import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../domain/workspace.dart';
import '../core/app_widgets.dart';
import '../core/palette_tokens.dart';
import 'workspace_dialogs.dart';
import 'workspace_panes.dart';
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
  bool _dragging = false, _closing = false;
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
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(vm.flushRecovery());
    }
    if (state == AppLifecycleState.resumed) unawaited(vm.checkExternal());
  }

  @override
  void onWindowClose() => unawaited(_close());
  @override
  void onWindowFocus() => unawaited(vm.checkExternal());
  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
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
    vm.endGuide();
    final dirty = vm.documents.where((d) => d.editor.session.isDirty).toList();
    if (dirty.isNotEmpty) {
      final decision = await showDialog<String>(
        context: context,
        builder: (context) => AppDialog(
          title: '还有未保存的内容',
          width: 460,
          actions: [
            AppButton(label: '取消', onPressed: () => Navigator.pop(context)),
            AppButton(
              label: '保留草稿并关闭',
              onPressed: () => Navigator.pop(context, 'draft'),
            ),
            AppButton(
              label: '全部保存',
              primary: true,
              onPressed: () => Navigator.pop(context, 'save'),
            ),
          ],
          child: Text(
            '${dirty.length} 篇文档尚未保存。可以保存到文件，或保留恢复草稿后关闭。',
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
    await vm.flushRecovery();
    if (widget.windowIntegration && _desktop) {
      await windowManager.destroy();
    } else if (Platform.isAndroid) {
      await SystemNavigator.pop();
    }
    _closing = false;
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
        e.replaceSelection('![图片说明](图片路径)');
      case 'inline-code':
        e.surround('`');
      case 'code':
        e.surround('```\n', '\n```');
      case 'table':
        e.replaceSelection('\n| 标题 | 内容 |\n| --- | --- |\n| 项目 | 说明 |\n');
      case 'rule':
        e.replaceSelection('\n\n---\n\n');
    }
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
        unawaited(showLayouts(context, vm));
      case 'appearance':
        unawaited(showAppearance(context, vm));
      case 'typography':
        unawaited(showAppearance(context, vm, typographyOnly: true));
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
    // Implemented by the native export service in the next verified unit.
    await showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: '导出与分享',
        child: Column(
          children: [
            const Text(
              'Markdown 使用标准 UTF-8 格式，便于继续编辑。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: '另存为 Markdown',
              icon: 'save',
              primary: true,
              onPressed: () {
                Navigator.pop(context);
                _action('save-as');
              },
            ),
          ],
        ),
      ),
    );
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
                            _banner('发现 ${state.recoverable.length} 篇恢复草稿', [
                              AppButton(
                                label: '恢复',
                                onPressed: state.restoreDrafts,
                              ),
                              AppButton(
                                label: '丢弃',
                                onPressed: () =>
                                    unawaited(_run(state.discardDrafts)),
                              ),
                            ]),
                          if (state.externalChange != null)
                            _banner('原文件已被其他程序修改', [
                              AppButton(
                                label: '重新载入',
                                onPressed: () async {
                                  if (state.editor.session.isDirty) {
                                    final yes = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AppDialog(
                                        title: '载入外部修改',
                                        actions: [
                                          AppButton(
                                            label: '取消',
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                          ),
                                          AppButton(
                                            label: '载入',
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                          ),
                                        ],
                                        child: const Text(
                                          '当前改动可以通过撤销恢复。确认载入外部文件的内容？',
                                        ),
                                      ),
                                    );
                                    if (yes != true) return;
                                  }
                                  state.reloadExternal();
                                },
                              ),
                              AppButton(
                                label: '另存当前内容',
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
                            label: '退出演示',
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
                                  '放开以打开 Markdown 文件',
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
          SvgPicture.asset('../../logo.svg', width: 22, height: 22),
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
          _menu('文件(F)', [
            ('新建文档', 'new', 'Ctrl+N'),
            ('打开…', 'open', 'Ctrl+O'),
            ('打开文件夹…', 'folder', ''),
            ('保存', 'save', 'Ctrl+S'),
            ('另存为…', 'save-as', 'Ctrl+Shift+S'),
            ('导出与分享…', 'export', ''),
            ('退出', 'exit', ''),
          ]),
          _menu('编辑(E)', [
            ('撤销', 'undo', 'Ctrl+Z'),
            ('重做', 'redo', 'Ctrl+Y'),
            ('剪切', 'cut', 'Ctrl+X'),
            ('复制', 'copy', 'Ctrl+C'),
            ('粘贴', 'paste', 'Ctrl+V'),
            ('全选', 'select-all', 'Ctrl+A'),
            ('查找', 'find', 'Ctrl+F'),
            ('替换', 'replace', 'Ctrl+H'),
          ]),
          _menu('插入(I)', [
            ('标题', 'format:heading', ''),
            ('引用', 'format:quote', ''),
            ('链接', 'format:link', ''),
            ('图片', 'format:image', ''),
            ('代码块', 'format:code', ''),
            ('表格', 'format:table', ''),
            ('分隔线', 'format:rule', ''),
          ]),
          _menu('视图(V)', [
            ('工作区布局…', 'layouts', ''),
            ('显示/隐藏侧栏', 'sidebar', ''),
            ('专注模式', 'focus', ''),
            ('演示模式', 'presentation', ''),
            ('外观与排版…', 'appearance', ''),
          ]),
          _menu('工具(T)', [
            ('导图摘要设置', 'summary', ''),
            ('导出与分享', 'export', ''),
            ('设置', 'settings', ''),
          ]),
          _menu('帮助(H)', [('快速上手', 'guide', ''), ('关于笺纬 / 检查更新', 'about', '')]),
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
              tooltip: '切换明暗模式',
              padding: 7,
              onPressed: () => state.updateAppearance(
                mode: Theme.of(context).brightness == Brightness.light
                    ? ThemeMode.dark
                    : ThemeMode.light,
              ),
            ),
            for (final palette in paletteNames.entries)
              Tooltip(
                message: palette.value,
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
              tooltip: '最小化',
              onPressed: () => windowManager.minimize(),
              height: 39,
              padding: 14,
            ),
            AppButton(
              icon: 'max',
              tooltip: '最大化 / 还原',
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
            tooltip: '关闭',
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
            tooltip: '文件与大纲',
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
            AppButton(
              label: '布局 ⌄',
              icon: 'columns',
              bordered: true,
              onPressed: () => _action('layouts'),
            ),
            const Spacer(),
            if (width >= 1100)
              AppButton(label: '• 快速上手', onPressed: () => _action('guide')),
          ],
          AppButton(
            icon: 'search',
            tooltip: '查找 · Ctrl+F',
            onPressed: () => _action('find'),
          ),
          const SizedBox(width: 6),
          AppButton(
            icon: 'save',
            label: phone ? null : '保存',
            bordered: true,
            tooltip: '保存 · Ctrl+S',
            onPressed: () => _action('save'),
          ),
          if (phone)
            _menu('•••', [
              ('新建', 'new', ''),
              ('打开…', 'open', ''),
              ('导出与分享', 'export', ''),
              ('外观与排版', 'appearance', ''),
              ('布局', 'layouts', ''),
              ('设置', 'settings', ''),
              ('快速上手', 'guide', ''),
              ('关于笺纬', 'about', ''),
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
            (WorkspaceLayout.instant, '编辑', 'edit'),
            (WorkspaceLayout.read, '阅读', 'eye'),
            (WorkspaceLayout.map, '导图', 'map'),
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
              label: '即时渲染',
              selected: state.layout.panes.contains('instant'),
              height: 26,
              onPressed: () => state.setLayout(
                state.layout.panes.contains('map')
                    ? WorkspaceLayout.instantMap
                    : WorkspaceLayout.instant,
              ),
            ),
            AppButton(
              label: '源码',
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
                    ('bold', '加粗', 'bold'),
                    ('italic', '斜体', 'italic'),
                    ('heading', '标题', 'heading'),
                    ('quote', '引用', 'quote'),
                    ('list', '无序列表', 'list'),
                    ('ordered', '有序列表', 'list-number'),
                    ('task', '任务列表', 'check'),
                    ('link', '链接', 'link'),
                    ('image', '图片', 'image'),
                    ('inline-code', '行内代码', 'code'),
                    ('code', '代码块', 'code'),
                    ('table', '表格', 'grid'),
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
                    tooltip: '更多格式',
                    onPressed: () => _action('format:rule'),
                    padding: 7,
                    height: 28,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: '排版 ${state.typography.label} ⌄',
            height: 28,
            onPressed: () => _action('typography'),
          ),
        ],
      ),
    );
  }

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
                  decoration: const InputDecoration(hintText: '查找文本'),
                ),
              ),
            ),
            const SizedBox(width: 5),
            AppButton(
              label: 'Aa',
              tooltip: '区分大小写',
              selected: state.matchCase,
              onPressed: () =>
                  state.search(_find.text, matchCase: !state.matchCase),
            ),
            AppButton(
              label: '.*',
              tooltip: '正则表达式',
              selected: state.regex,
              onPressed: () => state.search(_find.text, regex: !state.regex),
            ),
            if (!phone)
              AppButton(
                label: '整词',
                selected: state.wholeWord,
                onPressed: () =>
                    state.search(_find.text, wholeWord: !state.wholeWord),
              ),
            AppButton(
              icon: 'chevron',
              tooltip: '下一个',
              onPressed: () => state.nextMatch(),
            ),
            AppButton(
              label: '替换',
              onPressed: () => state.showFind(replace: !state.replaceVisible),
            ),
            AppButton(icon: 'x', tooltip: '关闭查找', onPressed: state.closeFind),
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
                      decoration: const InputDecoration(hintText: '替换为'),
                    ),
                  ),
                ),
                AppButton(
                  label: '替换',
                  onPressed: () => state.replaceCurrent(_replace.text),
                ),
                AppButton(
                  label: '全部替换',
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
                state.findError ?? '${state.matches.length} 处匹配',
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
            Text(state.editor.session.isDirty ? '未保存' : '未修改'),
            const SizedBox(width: 16),
            Text(state.layout.label, style: TextStyle(color: c.primary)),
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
            Text('行 ${position.line}，列 ${position.column}'),
            const SizedBox(width: 16),
            Text('${state.editor.session.text.characters.length} 字符'),
            const SizedBox(width: 16),
            Text(
              'UTF-8 · ${state.editor.document.newline == '\r\n' ? 'CRLF' : 'LF'}',
            ),
            const SizedBox(width: 10),
            AppButton(
              icon: 'palette',
              tooltip: '外观与排版',
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
          (WorkspaceLayout.instant, '写作', 'edit'),
          (WorkspaceLayout.read, '阅读', 'eye'),
          (WorkspaceLayout.map, '导图', 'map'),
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
    const steps = [
      ('写下第一句话', '点击正文，直接修改内容。即时编辑和源码使用同一份 Markdown。'),
      ('两个视角，同一份内容', '左侧编辑源码，右侧立即查看正文。试着添加一个标题。'),
      ('看见文章的脉络', '导图显示章节与正文摘要。拖动画布、折叠分支，试试双击章节。'),
      ('直接整理章节', '使用新增章节和编排工具，修改标题、正文、顺序或层级。所有改动都可以撤销。'),
      ('找到适合文字的排版', '打开排版，比较六种正文样式。配色与排版不会改变原文。'),
      ('开始自己的写作', '完成后恢复进入引导前的内容和撤销历史，再打开或新建自己的文档。'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Column(
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
          const SizedBox(width: 10),
          Wrap(
            spacing: 6,
            children: [
              AppButton(label: '结束', onPressed: state.endGuide),
              if (state.guideStep > 0)
                AppButton(
                  label: '上一步',
                  onPressed: () => state.advanceGuide(state.guideStep - 1),
                ),
              AppButton(
                label: state.guideStep == 5 ? '完成' : '下一步',
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
