import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_document_info.dart';
import 'workspace_outline.dart';
import 'workspace_panes.dart';
import 'workspace_view_model.dart';

/// One document companion, docked or overlaid by the workspace.
class WorkspaceAuxiliaryPanel extends StatefulWidget {
  const WorkspaceAuxiliaryPanel({
    super.key,
    required this.vm,
    required this.onClose,
    required this.onError,
    required this.onSaveDetails,
  });
  final WorkspaceViewModel vm;
  final VoidCallback onClose, onSaveDetails;
  final ValueChanged<Object> onError;

  @override
  State<WorkspaceAuxiliaryPanel> createState() =>
      _WorkspaceAuxiliaryPanelState();
}

class _WorkspaceAuxiliaryPanelState extends State<WorkspaceAuxiliaryPanel> {
  final _tabs = {for (final tab in WorkspaceAuxiliary.values) tab: FocusNode()};
  WorkspaceViewModel get vm => widget.vm;
  VoidCallback get onClose => widget.onClose;
  VoidCallback get onSaveDetails => widget.onSaveDetails;
  ValueChanged<Object> get onError => widget.onError;

  void _select(WorkspaceAuxiliary tab) {
    vm.showAuxiliary(tab);
    _tabs[tab]!.requestFocus();
  }

  @override
  void dispose() {
    for (final node in _tabs.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = Theme.of(context).colorScheme;
    final labels = [l.outline, l.articleInfo, l.chapterDetails];
    void move(int delta) => _select(
      WorkspaceAuxiliary.values[(vm.auxiliary.index + delta) %
          WorkspaceAuxiliary.values.length],
    );
    return Material(
      color: c.surfaceContainerLow,
      child: Column(
        children: [
          PanelHeader(
            title: l.documentAuxiliary,
            trailing: AppCloseButton(onPressed: onClose),
          ),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  move(-1),
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  move(1),
              const SingleActivator(LogicalKeyboardKey.home): () =>
                  _select(WorkspaceAuxiliary.outline),
              const SingleActivator(LogicalKeyboardKey.end): () =>
                  _select(WorkspaceAuxiliary.chapter),
            },
            child: FocusTraversalGroup(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: Row(
                  children: [
                    for (final tab in WorkspaceAuxiliary.values)
                      Expanded(
                        child: Semantics(
                          selected: vm.auxiliary == tab,
                          child: TextButton(
                            key: ValueKey('auxiliary-tab-${tab.name}'),
                            focusNode: _tabs[tab],
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(0, 32),
                              foregroundColor: vm.auxiliary == tab
                                  ? c.primary
                                  : c.onSurfaceVariant,
                              backgroundColor: vm.auxiliary == tab
                                  ? c.primary.withValues(alpha: .08)
                                  : null,
                              textStyle: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontSize: 11.5),
                            ),
                            onPressed: () => _select(tab),
                            child: Text(
                              labels[tab.index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (vm.auxiliary) {
              WorkspaceAuxiliary.outline => WorkspaceOutline(
                vm: vm,
                showHeader: false,
                onClose: onClose,
              ),
              WorkspaceAuxiliary.info => WorkspaceArticleInfo(
                vm: vm,
                onSaveDetails: onSaveDetails,
              ),
              WorkspaceAuxiliary.chapter =>
                vm.selectedHeading == null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AppGlyph('map', size: 26),
                            const SizedBox(height: 14),
                            Text(l.selectChapter),
                            const SizedBox(height: 8),
                            Text(
                              l.selectChapterHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppButton(
                              label: l.mindMap,
                              icon: 'map',
                              onPressed: () =>
                                  vm.setLayout(WorkspaceLayout.map),
                            ),
                          ],
                        ),
                      )
                    : ChapterInspector(
                        key: ValueKey(
                          '${vm.current.id}:${vm.selectedHeading!.header.start}',
                        ),
                        vm: vm,
                        onClose: onClose,
                        onError: onError,
                        embedded: true,
                      ),
            },
          ),
        ],
      ),
    );
  }
}
