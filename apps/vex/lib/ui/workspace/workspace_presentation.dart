import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_mindmap/vex_mindmap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../core/app_theme.dart';
import '../core/app_widgets.dart';
import 'document_image.dart';
import 'presentation_controller.dart';

class WorkspacePresentation extends StatelessWidget {
  const WorkspacePresentation({
    super.key,
    required this.controller,
    required this.typography,
    required this.fontSize,
    required this.onExit,
    this.documentPath,
    this.preferences = const MarkdownPreferences(),
  });

  final PresentationController controller;
  final MarkdownTypography typography;
  final double fontSize;
  final VoidCallback onExit;
  final String? documentPath;
  final MarkdownPreferences preferences;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): onExit,
      const SingleActivator(LogicalKeyboardKey.f5): onExit,
      const SingleActivator(LogicalKeyboardKey.arrowRight): controller.next,
      const SingleActivator(LogicalKeyboardKey.pageDown): controller.next,
      const SingleActivator(LogicalKeyboardKey.space): controller.next,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): controller.previous,
      const SingleActivator(LogicalKeyboardKey.pageUp): controller.previous,
      const SingleActivator(LogicalKeyboardKey.space, shift: true):
          controller.previous,
      const SingleActivator(LogicalKeyboardKey.home): () => controller.goTo(0),
      const SingleActivator(LogicalKeyboardKey.end): () =>
          controller.goTo(controller.deck.slides.length - 1),
    },
    child: FocusScope(
      autofocus: true,
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final c = Theme.of(context).colorScheme;
              final narrow = constraints.maxWidth < 700;
              return Material(
                color: c.surface,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceContainerLow,
                        border: Border(
                          bottom: BorderSide(color: c.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          AppButton(
                            key: const ValueKey('presentation-outline-toggle'),
                            icon: 'sidebar',
                            label: narrow ? null : context.l10n.outline,
                            tooltip: context.l10n.presentationOutline,
                            selected: controller.outline,
                            onPressed: controller.toggleOutline,
                            height: narrow ? 44 : 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              controller.deck.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          AppButton(
                            key: const ValueKey('presentation-markdown'),
                            icon: 'eye',
                            label: narrow
                                ? null
                                : context.l10n.presentationMarkdown,
                            tooltip: context.l10n.presentationMarkdown,
                            selected: !controller.mapMode,
                            height: narrow ? 44 : 32,
                            onPressed: () => controller.showMap(false),
                          ),
                          AppButton(
                            key: const ValueKey('presentation-map'),
                            icon: 'map',
                            label: narrow ? null : context.l10n.mindMap,
                            tooltip: context.l10n.mindMap,
                            selected: controller.mapMode,
                            height: narrow ? 44 : 32,
                            onPressed: () => controller.showMap(true),
                          ),
                          AppButton(
                            key: const ValueKey('presentation-exit'),
                            icon: 'x',
                            label: narrow
                                ? null
                                : context.l10n.exitPresentation,
                            tooltip: '${context.l10n.exitPresentation} · Esc',
                            onPressed: onExit,
                            height: narrow ? 44 : 32,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          if (controller.outline && !narrow)
                            SizedBox(
                              width: math.min(280, constraints.maxWidth * .25),
                              child: _PresentationOutline(
                                controller: controller,
                              ),
                            ),
                          Expanded(
                            child: narrow && controller.outline
                                ? _PresentationOutline(
                                    controller: controller,
                                    closeOnSelect: true,
                                  )
                                : controller.mapMode
                                ? _PresentationMap(controller: controller)
                                : Theme(
                                    data: documentTheme(Theme.of(context)),
                                    child: ColoredBox(
                                      color: documentTheme(Theme.of(context))
                                          .colorScheme
                                          .surface,
                                      child: _PresentationBody(
                                        key: ValueKey(controller.page),
                                        controller: controller,
                                        typography: typography,
                                        fontSize: fontSize * controller.scale,
                                        preferences: preferences,
                                        documentPath: documentPath,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceContainerLow,
                        border: Border(
                          top: BorderSide(color: c.outlineVariant),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!narrow)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Text(
                                context.l10n.presentationKeys,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              AppButton(
                                key: const ValueKey('presentation-smaller'),
                                label: controller.mapMode ? '−' : 'A−',
                                tooltip: controller.mapMode
                                    ? context.l10n.mapLabels.zoomOut
                                    : context.l10n.presentationSmaller,
                                height: narrow ? 44 : 32,
                                onPressed: controller.mapMode
                                    ? () => controller.map.zoom(
                                        1 / 1.15,
                                        controller.mapViewport,
                                      )
                                    : controller.scale > 1
                                    ? () => controller.resize(
                                        controller.scale - .1,
                                      )
                                    : null,
                              ),
                              if (!narrow)
                                ListenableBuilder(
                                  listenable: controller.map,
                                  builder: (context, _) => Text(
                                    '${((controller.mapMode ? controller.map.scale : controller.scale) * 100).round()}%',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              AppButton(
                                key: const ValueKey('presentation-larger'),
                                label: controller.mapMode ? '+' : 'A+',
                                tooltip: controller.mapMode
                                    ? context.l10n.mapLabels.zoomIn
                                    : context.l10n.presentationLarger,
                                height: narrow ? 44 : 32,
                                onPressed: controller.mapMode
                                    ? () => controller.map.zoom(
                                        1.15,
                                        controller.mapViewport,
                                      )
                                    : controller.scale < 2.5
                                    ? () => controller.resize(
                                        controller.scale + .1,
                                      )
                                    : null,
                              ),
                              if (controller.mapMode)
                                AppButton(
                                  key: const ValueKey('presentation-map-fit'),
                                  icon: 'fit',
                                  tooltip: context.l10n.mapLabels.fitCanvas,
                                  height: narrow ? 44 : 32,
                                  onPressed: () => controller.map.fit(
                                    controller.mapViewport,
                                  ),
                                ),
                              const Spacer(),
                              AppButton(
                                key: const ValueKey('presentation-previous'),
                                icon: 'arrow-left',
                                label: narrow
                                    ? null
                                    : context.l10n.presentationPrevious,
                                tooltip: context.l10n.presentationPrevious,
                                height: narrow ? 44 : 32,
                                onPressed: controller.hasPrevious
                                    ? controller.previous
                                    : null,
                              ),
                              Semantics(
                                liveRegion: true,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    '${controller.page + 1} / ${controller.deck.slides.length}',
                                    key: const ValueKey(
                                      'presentation-progress',
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                              AppButton(
                                key: const ValueKey('presentation-next'),
                                icon: 'chevron',
                                label: narrow
                                    ? null
                                    : context.l10n.presentationNext,
                                tooltip: context.l10n.presentationNext,
                                height: narrow ? 44 : 32,
                                onPressed: controller.hasNext
                                    ? controller.next
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    LinearProgressIndicator(
                      value:
                          (controller.page + 1) / controller.deck.slides.length,
                      minHeight: 2,
                      backgroundColor: c.surfaceContainerLow,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _PresentationOutline extends StatefulWidget {
  const _PresentationOutline({
    required this.controller,
    this.closeOnSelect = false,
  });
  final PresentationController controller;
  final bool closeOnSelect;
  @override
  State<_PresentationOutline> createState() => _PresentationOutlineState();
}

class _PresentationOutlineState extends State<_PresentationOutline> {
  late final _scroll = ScrollController(
    initialScrollOffset: math.max(0, (widget.controller.page - 2) * 44),
  );
  @override
  void didUpdateWidget(_PresentationOutline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_scroll.hasClients) {
      final position = widget.controller.page * 44.0;
      if (position < _scroll.offset ||
          position + 44 > _scroll.offset + _scroll.position.viewportDimension) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(position.clamp(0, _scroll.position.maxScrollExtent));
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller, c = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        border: Border(right: BorderSide(color: c.outlineVariant)),
      ),
      child: ListView.builder(
        key: const ValueKey('presentation-outline'),
        controller: _scroll,
        itemExtent: 44,
        itemCount: controller.deck.slides.length,
        itemBuilder: (context, index) {
          final slide = controller.deck.slides[index],
              selected = index == controller.page;
          return Semantics(
            selected: selected,
            child: Material(
              color: selected ? c.primaryContainer : Colors.transparent,
              child: InkWell(
                key: ValueKey('presentation-page-$index'),
                onTap: () {
                  controller.goTo(index);
                  if (widget.closeOnSelect) controller.toggleOutline();
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 12 + (slide.level - 1) * 10,
                    right: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          slide.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? c.onPrimaryContainer
                                : c.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PresentationMap extends StatefulWidget {
  const _PresentationMap({required this.controller});
  final PresentationController controller;
  @override
  State<_PresentationMap> createState() => _PresentationMapState();
}

class _PresentationMapState extends State<_PresentationMap> {
  int? _lastPage;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final controller = widget.controller, viewport = constraints.biggest;
      if (_lastPage != controller.page || controller.mapViewport != viewport) {
        _lastPage = controller.page;
        controller.mapViewport = viewport;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            controller.map.focusNode('slide-${controller.page}', viewport);
          }
        });
      }
      return MindMapView(
        key: const ValueKey('presentation-map-canvas'),
        controller: controller.map,
        labels: context.l10n.mapLabels,
        enableKeyboardNavigation: false,
        showControls: false,
        onSelect: (node) => controller.goTo(int.parse(node.id.substring(6))),
        onActivate: (node) {
          controller.goTo(int.parse(node.id.substring(6)));
          controller.showMap(false);
        },
        nodeBuilder: (context, node, selected) {
          final c = Theme.of(context).colorScheme;
          final root = node.id == controller.map.root.id;
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: root
                  ? c.primary
                  : selected
                  ? c.primaryContainer
                  : c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? c.primary : c.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: root
                    ? c.onPrimary
                    : selected
                    ? c.onPrimaryContainer
                    : c.onSurface,
              ),
            ),
          );
        },
      );
    },
  );
}

class _PresentationBody extends StatelessWidget {
  const _PresentationBody({
    super.key,
    required this.controller,
    required this.typography,
    required this.fontSize,
    this.documentPath,
    this.preferences = const MarkdownPreferences(),
  });
  final PresentationController controller;
  final MarkdownTypography typography;
  final double fontSize;
  final String? documentPath;
  final MarkdownPreferences preferences;
  @override
  Widget build(BuildContext context) {
    final deck = controller.deck, slide = controller.slide;
    final count = slide.endBlock - slide.firstBlock;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.max(typography.width, 1120)),
        child: SuperListView.builder(
          key: ValueKey('presentation-body-${controller.page}'),
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 700 ? 22 : 52,
            32,
            32,
            48,
          ),
          itemCount: math.max(count, 1),
          itemBuilder: (context, index) => count == 0
              ? Text(context.l10n.emptyDocument)
              : MarkdownReader(
                  documentSource: deck.document.source,
                  labels: context.l10n.editorLabels,
                  imageBuilder: (uri, title, alt) => DocumentImage(
                    uri: uri,
                    documentPath: documentPath,
                    alt: alt,
                  ),
                  data: deck.document.blocks[slide.firstBlock + index].range
                      .slice(deck.document.source),
                  typography: typography,
                  fontSize: fontSize,
                  preferences: preferences,
                  onTapLink: (_, href, _) {
                    final uri = Uri.tryParse(href ?? '');
                    if (uri != null &&
                        ['https', 'http', 'mailto'].contains(uri.scheme)) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
        ),
      ),
    );
  }
}
