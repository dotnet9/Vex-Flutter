import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_view_model.dart';

Future<void> showSaveStatus(
  BuildContext context,
  WorkspaceViewModel vm,
) => showDialog<void>(
  context: context,
  builder: (context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final l = context.l10n, doc = vm.current;
      Future<void> save({bool saveAs = false}) async {
        try {
          await vm.save(saveAs: saveAs, document: doc);
        } catch (_) {
          // The persistent status below owns the error and retry action.
        }
      }

      return AppDialog(
        title: l.saveDetails,
        width: 520,
        actions: [
          AppButton(label: l.close, onPressed: () => Navigator.pop(context)),
          AppButton(
            label: l.saveAs,
            onPressed: doc.saving || vm.guiding
                ? null
                : () => save(saveAs: true),
          ),
          AppButton(
            label: l.save,
            primary: true,
            onPressed: doc.saving || vm.guiding ? null : save,
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vm.saveState,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SelectableText(
                '${l.propertyLocation}\n${doc.path ?? l.newUnsaved}',
              ),
              const SizedBox(height: 12),
              Text(
                '${l.lastSaved}\n${doc.lastSavedAt?.toLocal().toString().split('.').first ?? l.noSaveYet}',
              ),
              const SizedBox(height: 12),
              Text(
                '${l.draftStatus}\n${!vm.filePreferences.recovery
                    ? l.draftDisabled
                    : vm.recoveryError != null
                    ? l.recoverySaveFailed(vm.recoveryError.toString())
                    : !vm.editor.session.isDirty
                    ? l.draftNone
                    : vm.currentDraftSaved
                    ? l.draftProtected
                    : l.draftPending}',
              ),
              if (doc.saveError != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  doc.saveError.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      );
    },
  ),
);

Future<void> showRecoveryDrafts(BuildContext context, WorkspaceViewModel vm) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final l = context.l10n;
        return AppDialog(
          title: l.draftReview,
          width: 780,
          actions: [
            AppButton(label: l.cancel, onPressed: () => Navigator.pop(context)),
            AppButton(
              label: l.restore,
              primary: true,
              onPressed: () async {
                await vm.restoreDrafts();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
          child: SizedBox(
            height: (MediaQuery.sizeOf(context).height * .55).clamp(140, 480),
            child: ListView(
              children: [
                Text(l.draftCompareHint, style: const TextStyle(fontSize: 13)),
                for (final draft in vm.recoverable)
                  ExpansionTile(
                    initiallyExpanded: vm.recoverable.length == 1,
                    tilePadding: EdgeInsets.zero,
                    title: Text(draft['name'] as String? ?? l.untitledFile),
                    subtitle: Text(
                      '${l.draftSource}: ${draft['path'] ?? l.newUnsaved}',
                    ),
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          Widget content(String title, Object? value) =>
                              SizedBox(
                                height: 220,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLow,
                                        padding: const EdgeInsets.all(10),
                                        child: SingleChildScrollView(
                                          child: SelectableText(
                                            value as String? ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                          final saved = content(l.savedContent, draft['saved']);
                          final recovered = content(
                            l.recoveryContent,
                            draft['text'],
                          );
                          return constraints.maxWidth < 500
                              ? Column(
                                  children: [
                                    saved,
                                    const SizedBox(height: 12),
                                    recovered,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: saved),
                                    const SizedBox(width: 12),
                                    Expanded(child: recovered),
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
