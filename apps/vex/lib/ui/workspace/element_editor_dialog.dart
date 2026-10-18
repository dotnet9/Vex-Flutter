import 'package:flutter/material.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';

typedef ElementEditResult = ({
  String source,
  String language,
  String url,
  String description,
  String title,
});

Future<ElementEditResult?> showElementEditor(
  BuildContext context,
  MarkdownElementTarget target, {
  bool? image,
  Future<({String url, String description})?> Function()? onPickImage,
}) => showDialog<ElementEditResult>(
  context: context,
  builder: (_) =>
      _ElementEditor(target, image: image, onPickImage: onPickImage),
);

class _ElementEditor extends StatefulWidget {
  const _ElementEditor(this.target, {this.image, this.onPickImage});
  final MarkdownElementTarget target;
  final bool? image;
  final Future<({String url, String description})?> Function()? onPickImage;
  @override
  State<_ElementEditor> createState() => _ElementEditorState();
}

class _ElementEditorState extends State<_ElementEditor> {
  late final _source = TextEditingController(text: widget.target.code);
  late final _language = TextEditingController(
    text: MarkdownCodeFence.parse(widget.target.raw)?.language ?? '',
  );
  late final _url = TextEditingController(
    text: widget.target.media?.url ?? 'https://',
  );
  late final _description = TextEditingController(
    text:
        widget.target.media?.description ??
        markdownPlainText(widget.target.selected),
  );
  late final _title = TextEditingController(
    text: widget.target.media?.title ?? '',
  );
  String? _error;
  bool _picking = false;
  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await widget.onPickImage!();
      if (!mounted || picked == null) return;
      _url.text = picked.url;
      if (_description.text.isEmpty) _description.text = picked.description;
    } catch (error) {
      if (mounted) {
        setState(() => _error = context.l10n.operationFailed(error.toString()));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_source, _language, _url, _description, _title]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, media = widget.target.media;
    final mediaMode = media != null || widget.image != null;
    final image = widget.image ?? media?.image ?? false;
    final code = widget.target.block.kind == MarkdownBlockKind.code;
    Widget field(
      String key,
      String label,
      TextEditingController controller, {
      int lines = 1,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        key: ValueKey('element-edit-$key'),
        controller: controller,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 14,
        autocorrect: false,
        enableSuggestions: false,
        style: TextStyle(
          fontSize: 14,
          height: 1.7,
          fontFamily: key == 'source' ? 'Cascadia Code' : null,
        ),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          suffixIcon: key == 'url' && image && widget.onPickImage != null
              ? AppButton(
                  icon: 'folder',
                  tooltip: l.localFiles,
                  height: 40,
                  onPressed: _picking ? null : _pick,
                )
              : null,
        ),
      ),
    );
    return AppDialog(
      title: mediaMode
          ? image
                ? l.elementEditImage
                : l.elementEditLink
          : !code
          ? l.elementEditMath
          : widget.target.diagram
          ? l.elementEditDiagram
          : l.elementEditCode,
      width: mediaMode ? 480 : 680,
      actions: [
        AppButton(label: l.cancel, onPressed: () => Navigator.pop(context)),
        AppButton(
          key: const ValueKey('element-edit-apply'),
          label: l.apply,
          primary: true,
          onPressed: _picking
              ? null
              : () {
                  if (mediaMode &&
                      (_url.text.trim().isEmpty ||
                          _url.text.trim() == 'https://' ||
                          Uri.tryParse(_url.text.trim()) == null)) {
                    setState(() => _error = l.elementInvalidAddress);
                    return;
                  }
                  if (!mediaMode &&
                      code &&
                      RegExp(r'[\s`~]').hasMatch(_language.text.trim())) {
                    setState(() => _error = l.elementInvalidLanguage);
                    return;
                  }
                  Navigator.pop<ElementEditResult>(context, (
                    source: _source.text,
                    language: _language.text.trim(),
                    url: _url.text,
                    description: _description.text,
                    title: _title.text,
                  ));
                },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ...(mediaMode
              ? [
                  field('url', l.elementAddress, _url),
                  field('description', l.elementDescription, _description),
                  field('title', l.elementTitle, _title),
                ]
              : [
                  if (code) field('language', l.elementLanguage, _language),
                  field('source', l.elementSource, _source, lines: 5),
                  if (widget.target.diagram)
                    ValueListenableBuilder(
                      valueListenable: _source,
                      builder: (_, value, _) => MarkdownMermaidBlock(
                        source: value.text,
                        labels: l.editorLabels,
                        composing:
                            value.composing.isValid &&
                            !value.composing.isCollapsed,
                      ),
                    ),
                ]),
        ],
      ),
    );
  }
}
