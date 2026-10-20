import 'package:flutter/material.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_view_model.dart';

/// Desktop document structure is independent of the file navigator.
class WorkspaceOutline extends StatefulWidget {
  const WorkspaceOutline({super.key, required this.vm, required this.onClose});
  final WorkspaceViewModel vm;
  final VoidCallback onClose;

  @override
  State<WorkspaceOutline> createState() => _WorkspaceOutlineState();
}

class _WorkspaceOutlineState extends State<WorkspaceOutline> {
  late final _search = TextEditingController(text: widget.vm.outlineFilter);
  final _scroll = ScrollController();
  MarkdownDocument? _document;
  String? _query, _followedId;
  List<(MarkdownHeading, String)> _headings = [];
  static const _rowHeight = 32.0;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm, c = Theme.of(context).colorScheme;
    final query = vm.outlineFilter.trim().toLowerCase();
    if (_search.text != vm.outlineFilter) _search.text = vm.outlineFilter;
    if (!identical(_document, vm.editor.document) || _query != query) {
      _document = vm.editor.document;
      _query = query;
      final counters = List.filled(6, 0);
      _headings = [
        for (final heading in _document!.headings)
          (() {
            counters[heading.level - 1]++;
            for (var level = heading.level; level < 6; level++) {
              counters[level] = 0;
            }
            return (heading, counters.take(heading.level).join('.'));
          })(),
      ].where((entry) => entry.$1.title.toLowerCase().contains(query)).toList();
      _followedId = null;
    }
    if (_followedId != vm.selectedHeadingId) {
      _followedId = vm.selectedHeadingId;
      final index = _headings.indexWhere((e) => e.$1.id == _followedId);
      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          final top = index * _rowHeight + 12;
          final position = _scroll.position;
          final bottom = top + _rowHeight;
          if (top < position.pixels ||
              bottom > position.pixels + position.viewportDimension) {
            _scroll.jumpTo(
              (top - position.viewportDimension / 3).clamp(
                0.0,
                position.maxScrollExtent,
              ),
            );
          }
        });
      }
    }
    return ColoredBox(
      color: c.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.documentStructure,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AppButton(
                  icon: 'chevron-down',
                  tooltip: context.l10n.outline,
                  height: 26,
                  padding: 4,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                key: const ValueKey('outline-search'),
                controller: _search,
                onChanged: vm.setOutlineFilter,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  fillColor: c.surfaceContainerLow,
                  hintText: context.l10n.searchOutline,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(8),
                    child: AppGlyph('search'),
                  ),
                  prefixIconConstraints: const BoxConstraints(maxWidth: 32),
                  suffixIconConstraints: const BoxConstraints(maxWidth: 32),
                  suffixIcon: query.isEmpty
                      ? null
                      : AppButton(
                          icon: 'x',
                          tooltip: context.l10n.clearSearch,
                          height: 30,
                          padding: 4,
                          onPressed: () => vm.setOutlineFilter(''),
                        ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _headings.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      query.isEmpty
                          ? context.l10n.outlineHint
                          : context.l10n.noSearchResults,
                      style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    key: ValueKey('structure-${vm.current.id}'),
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
                    itemExtent: _rowHeight,
                    itemCount: _headings.length,
                    itemBuilder: (context, index) {
                      final (heading, number) = _headings[index];
                      final selected =
                          (vm.selectedHeadingId ??
                              _document!.headings.first.id) ==
                          heading.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: TextButton(
                          key: ValueKey('structure-heading-${heading.id}'),
                          onPressed: () => vm.selectHeading(heading),
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(
                              left: (heading.level - 1) * 12.0,
                              right: 6,
                            ),
                            minimumSize: Size.zero,
                            foregroundColor: selected ? c.primary : c.onSurface,
                            backgroundColor: selected
                                ? c.primary.withValues(alpha: .09)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            textStyle: Theme.of(context).textTheme.labelMedium!
                                .copyWith(fontSize: 12.5),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                child: Center(
                                  child: Container(
                                    width: heading.level == 1 ? 3 : 8,
                                    height: heading.level == 1 ? 11 : 2,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? c.primary
                                          : c.outlineVariant,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 37,
                                child: Text(
                                  number,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: selected
                                        ? c.primary
                                        : c.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  heading.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
