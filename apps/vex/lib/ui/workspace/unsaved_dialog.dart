import 'package:flutter/material.dart';

import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';

Future<String?> showUnsavedDialog(
  BuildContext context,
  List<WorkspaceDocument> documents, {
  required bool recovery,
}) => showDialog<String>(
  context: context,
  builder: (context) => AppDialog(
    title: context.l10n.exitTitle,
    width: 500,
    actions: [
      AppButton(
        label: context.l10n.continueWriting,
        onPressed: () => Navigator.pop(context),
      ),
      AppButton(
        label: recovery ? context.l10n.keepDraftClose : context.l10n.discard,
        onPressed: () => Navigator.pop(context, recovery ? 'draft' : 'discard'),
      ),
      AppButton(
        label: documents.length > 1 ? context.l10n.saveAll : context.l10n.save,
        icon: 'save',
        primary: true,
        onPressed: () => Navigator.pop(context, 'save'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 12),
              child: AppGlyph(
                'file',
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Expanded(
              child: Text(
                recovery
                    ? context.l10n.exitBody
                    : context.l10n.unsavedDocuments(documents.length),
                style: const TextStyle(fontSize: 14, height: 1.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final document in documents)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                const AppGlyph('edit'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    document.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  ),
);
