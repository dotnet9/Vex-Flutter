import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:val_latex_flutter/val_latex_flutter.dart' as latex;
import 'package:vex_markdown_core/vex_markdown_core.dart';

import 'controller.dart';
import 'heading_anchors.dart';
import 'markdown_preferences.dart';
import 'markdown_syntax.dart';

final class MarkdownMediaTarget {
  const MarkdownMediaTarget({
    required this.range,
    required this.labelRange,
    required this.image,
    required this.url,
    required this.title,
    required this.description,
  });
  final SourceRange range, labelRange;
  final bool image;
  final String url, title, description;
}

/// Immutable source snapshot shared by all element menus and edit dialogs.
final class MarkdownElementTarget {
  MarkdownElementTarget._(
    this.controller,
    this.source,
    this.revision,
    this.offset,
    this.block,
    this.selection,
    this.media,
    this.mediaItems,
  );
  final MarkdownEditorController controller;
  final String source;
  final int revision, offset;
  final MarkdownBlock block;
  final TextSelection selection;
  final MarkdownMediaTarget? media;
  final List<MarkdownMediaTarget> mediaItems;
  bool get isCurrent =>
      controller.session.revision == revision && controller.text == source;
  bool get hasSelection => selection.isValid && !selection.isCollapsed;
  String get raw => block.range.slice(source);
  String get selected => hasSelection ? selection.textInside(source) : '';
  String get newline => controller.document.newline;
  bool get textBlock => !const [
    MarkdownBlockKind.table,
    MarkdownBlockKind.code,
    MarkdownBlockKind.math,
    MarkdownBlockKind.rule,
  ].contains(block.kind);
  bool get diagram =>
      block.kind == MarkdownBlockKind.code &&
      MarkdownCodeFence.parse(raw)?.language.toLowerCase() == 'mermaid';
  String get code => block.kind == MarkdownBlockKind.code
      ? MarkdownCodeFence.parse(raw)?.code ?? raw
      : block.kind == MarkdownBlockKind.math
      ? _formula?.tex.trim() ?? raw
      : raw;
  latex.MathSegment? get _formula =>
      const latex.MathScanner(environments: false)
          .scan(raw)
          .whereType<latex.MathSegment>()
          .firstOrNull;
  String get line {
    final start = offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;
    final next = source.indexOf('\n', offset);
    return source.substring(start, next < 0 ? source.length : next);
  }

  bool get task => RegExp(r'^\s*[-+*]\s+\[[ xX]\]').hasMatch(line);
  bool get canOutdent => RegExp(r'^[ \t]+').hasMatch(line);

  void validate() {
    if (!isCurrent) throw StateError('Document changed');
  }

  void replace(SourceRange range, String value, {String label = '编辑元素'}) {
    validate();
    controller.session.patch(TextPatch(range, value), label: label);
    controller.select(range.start + value.length);
  }

  void restoreSelection() {
    validate();
    controller.select(selection.baseOffset, selection.extentOffset);
  }

  void deleteBlock() => replace(block.range, '', label: '删除元素');

  void insertParagraph({required bool above}) {
    validate();
    final at = above ? block.range.start : block.range.end;
    final padding = above || raw.endsWith(newline)
        ? newline
        : '$newline$newline';
    replace(SourceRange(at, at), '$padding$newline', label: '插入段落');
    controller.select(above ? at : at + padding.length);
  }

  void indent(int size, {bool reverse = false}) {
    validate();
    if (block.kind != MarkdownBlockKind.list) return;
    final start = offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;
    final indentation = RegExp(r'^[ \t]+').firstMatch(line)?.group(0) ?? '';
    if (reverse) {
      final count = indentation.startsWith('\t')
          ? 1
          : indentation.length.clamp(0, size);
      if (count > 0) replace(SourceRange(start, start + count), '');
    } else {
      replace(SourceRange(start, start), ' ' * size);
    }
  }

  void toggleTask() {
    validate();
    final match = RegExp(r'^\s*[-+*]\s+\[([ xX])\]').firstMatch(line);
    if (match == null) return;
    final start = offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;
    final at = start + match.end - 2;
    replace(SourceRange(at, at + 1), match[1] == ' ' ? 'x' : ' ');
  }

  void unlink() {
    final token = media;
    if (token == null) return;
    replace(token.range, token.image ? '' : token.labelRange.slice(source));
  }

  void editMedia(String url, String description, {String title = ''}) {
    final token = media;
    if (token == null) return;
    replace(
      token.range,
      markdownMediaSource(
        url,
        description,
        title: title,
        image: token.image,
        rawLabel: description == token.description
            ? token.labelRange.slice(source)
            : null,
      ),
    );
  }

  void insertMedia(
    String url,
    String description, {
    String title = '',
    bool image = false,
  }) {
    restoreSelection();
    controller.replaceSelection(
      markdownMediaSource(url, description, title: title, image: image),
    );
  }

  void editFormula(String content) {
    validate();
    final formula = _formula;
    if (formula == null || content == code) return;
    final ending = raw.endsWith(newline) ? newline : '';
    replace(
      block.range,
      '${formula.open}$newline${content.replaceAll(RegExp(r'\r\n|\r|\n'), newline)}$newline${formula.close}$ending',
    );
  }

  void editCode(String content, String language) {
    validate();
    final fence = MarkdownCodeFence.parse(raw);
    if (fence == null) return;
    replace(block.range, fence.replace(code: content, language: language));
  }
}

String markdownMediaSource(
  String url,
  String description, {
  String title = '',
  bool image = false,
  String? rawLabel,
}) {
  String escapeLabel(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]')
      .replaceAll(RegExp(r'[\r\n]'), ' ');
  final destination = Uri.parse(url.trim())
      .toString()
      .replaceAll('<', '%3C')
      .replaceAll('>', '%3E');
  final caption = title.isEmpty
      ? ''
      : ' "${title.replaceAll(RegExp(r'[\r\n]'), ' ').replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  return '${image ? '!' : ''}[${rawLabel ?? escapeLabel(description)}](<$destination>$caption)';
}

extension MarkdownElementEditing on MarkdownEditorController {
  MarkdownElementTarget elementTarget({int? offset, TextSelection? selection}) {
    final at = (offset ?? (this.selection.isValid ? this.selection.start : 0))
        .clamp(0, text.length);
    final block =
        document.blocks.where((b) => b.range.contains(at)).firstOrNull ??
        (at == text.length
            ? document.blocks.where((b) => b.range.end == at).lastOrNull
            : null) ??
        MarkdownBlock(MarkdownBlockKind.paragraph, SourceRange(at, at), 1);
    final selected =
        selection ??
        (this.selection.isValid &&
                this.selection.start <= at &&
                at <= this.selection.end
            ? this.selection
            : TextSelection.collapsed(offset: at));
    final tokens =
        const [
          MarkdownBlockKind.code,
          MarkdownBlockKind.math,
        ].contains(block.kind)
        ? <MarkdownMediaTarget>[]
        : markdownMediaTargets(text, block);
    final matches = tokens.where((item) => item.range.contains(at)).toList()
      ..sort((a, b) => a.range.length.compareTo(b.range.length));
    final media = matches.firstOrNull;
    return MarkdownElementTarget._(
      this,
      text,
      session.revision,
      at,
      block,
      selected,
      media,
      List.unmodifiable(tokens),
    );
  }
}

/// CommonMark resolves nested destinations, escapes and reference definitions.
/// Only source coordinates are added here; link parsing stays in package:markdown.
List<MarkdownMediaTarget> markdownMediaTargets(
  String source,
  MarkdownBlock block,
) {
  final targets = <MarkdownMediaTarget>[];
  var capturing = false;
  void capture(
    md.InlineParser parser,
    md.SimpleDelimiter opener,
    int labelEnd,
    Iterable<md.Node>? result,
  ) {
    if (!capturing) return;
    final node = result?.whereType<md.Element>().firstOrNull;
    if (node == null || !['a', 'img'].contains(node.tag)) return;
    final start = block.range.start + opener.endPos - opener.length;
    final end = block.range.start + parser.pos + 1;
    if (end > block.range.end) return;
    targets.add(
      MarkdownMediaTarget(
        range: SourceRange(start, end),
        labelRange: SourceRange(
          block.range.start + opener.endPos,
          block.range.start + labelEnd,
        ),
        image: node.tag == 'img',
        url: markdownAttributeText(
          node.attributes[node.tag == 'img' ? 'src' : 'href'] ?? '',
        ),
        title: markdownAttributeText(node.attributes['title'] ?? ''),
        description: node.tag == 'img'
            ? markdownAttributeText(node.attributes['alt'] ?? '')
            : node.textContent,
      ),
    );
  }

  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: [_PositionedImage(capture), _PositionedLink(capture)],
    encodeHtml: false,
  );
  // Collect definitions once, then parse the unchanged block to retain offsets.
  document.parseLines(source.split(RegExp(r'\r?\n')));
  capturing = true;
  md.InlineParser(block.range.slice(source), document).parse();
  return targets;
}

String markdownAttributeText(String value) => md.InlineParser(
  value,
  md.Document(
    encodeHtml: false,
    withDefaultInlineSyntaxes: false,
    inlineSyntaxes: [md.DecodeHtmlSyntax()],
  ),
).parse().map((node) => node.textContent).join();

typedef _CaptureMedia = void Function(
  md.InlineParser,
  md.SimpleDelimiter,
  int,
  Iterable<md.Node>?,
);

class _PositionedLink extends md.LinkSyntax {
  _PositionedLink(this.capture);
  final _CaptureMedia capture;
  @override
  Iterable<md.Node>? close(
    md.InlineParser parser,
    covariant md.SimpleDelimiter opener,
    md.Delimiter? closer, {
    String? tag,
    required List<md.Node> Function() getChildren,
  }) {
    final end = parser.pos;
    final result = super.close(
      parser,
      opener,
      closer,
      tag: tag,
      getChildren: getChildren,
    );
    capture(parser, opener, end, result);
    return result;
  }
}

class _PositionedImage extends md.ImageSyntax {
  _PositionedImage(this.capture);
  final _CaptureMedia capture;
  @override
  Iterable<md.Node>? close(
    md.InlineParser parser,
    covariant md.SimpleDelimiter opener,
    md.Delimiter? closer, {
    String? tag,
    required List<md.Node> Function() getChildren,
  }) {
    final end = parser.pos;
    final result = super.close(
      parser,
      opener,
      closer,
      tag: tag,
      getChildren: getChildren,
    );
    capture(parser, opener, end, result);
    return result;
  }
}

String markdownPlainText(String source) {
  const preferences = MarkdownPreferences();
  final nodes = md.Document(
    extensionSet: MarkdownSyntax.extensions(preferences),
    inlineSyntaxes: MarkdownSyntax.inlines(preferences),
    blockSyntaxes: MarkdownSyntax.blocks(preferences),
    encodeHtml: false,
  ).parseLines(source.split(RegExp(r'\r?\n')));
  String plain(md.Node node) {
    if (node is! md.Element) return node.textContent;
    if (node.tag == 'img') return node.attributes['alt'] ?? '';
    if (node.tag == 'br') return '\n';
    return node.children
            ?.map(plain)
            .join(
              ['ul', 'ol', 'table', 'thead', 'tbody'].contains(node.tag)
                  ? '\n'
                  : node.tag == 'tr'
                  ? '\t'
                  : '',
            ) ??
        '';
  }

  return nodes.map(plain).join('\n\n');
}

String markdownHtmlFragment(String source, MarkdownPreferences preferences) {
  final parser = md.Document(
    extensionSet: MarkdownSyntax.extensions(preferences),
    inlineSyntaxes: MarkdownSyntax.inlines(preferences),
    blockSyntaxes: MarkdownSyntax.blocks(preferences),
  );
  final nodes = parser.parseLines(source.split(RegExp(r'\r\n|\n|\r')));
  MarkdownHeadingIds().assign(nodes, encodedHtml: true);
  return md.renderToHtml(nodes);
}
