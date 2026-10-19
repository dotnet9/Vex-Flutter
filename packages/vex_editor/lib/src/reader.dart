import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:vex_markdown_core/vex_markdown_core.dart';

import 'code_block.dart';
import 'editing_preferences.dart';
import 'element_target.dart';
import 'font_families.dart';
import 'heading_anchors.dart';
import 'labels.dart';
import 'markdown_preferences.dart';
import 'markdown_syntax.dart';
import 'math_formula.dart';
import 'mermaid_block.dart';

part 'reader_link_context.dart';

typedef MarkdownMediaContextCallback = void Function(
  String url,
  bool image,
  int occurrence,
  Offset position,
);

enum MarkdownTypography {
  simple('简约', '日常写作 · 清爽留白'),
  document('文档', '知识整理 · 清晰分节'),
  book('书卷', '散文长读 · 衬线字形'),
  technical('技术', '开发笔记 · 信息模块'),
  column('专栏', '观点文章 · 鲜明层次'),
  editorial('刊物', '发布阅读 · 窄栏节奏'),
  academic('学术', '论述长文 · 克制层次'),
  journal('手札', '随笔记录 · 轻柔衬线'),
  handbook('手册', '操作参考 · 醒目分节');

  const MarkdownTypography(this.label, this.description);
  final String label, description;
  double get width => switch (this) {
    book => 800,
    technical => 1040,
    column => 880,
    editorial => 760,
    academic => 900,
    journal => 800,
    _ => 960,
  };
  bool get serif => const [book, academic, journal].contains(this);
  bool get centered => this == editorial || this == academic;
  Color accent(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      simple => Color(dark ? 0xffdfe3e8 : 0xff343b43),
      document || technical => Color(dark ? 0xff97bde0 : 0xff376c9a),
      book => Color(dark ? 0xffd3bc9a : 0xff70604f),
      column => Color(dark ? 0xffeba88d : 0xffa04d35),
      editorial => Color(dark ? 0xff8ac8b3 : 0xff24766b),
      academic => Color(dark ? 0xffbdc6d7 : 0xff4a5363),
      journal => Color(dark ? 0xffc7a6d9 : 0xff77558a),
      handbook => Color(dark ? 0xff9bcfb4 : 0xff39765d),
    };
  }
}

class MarkdownReader extends StatelessWidget {
  const MarkdownReader({
    super.key,
    required this.data,
    this.typography = MarkdownTypography.simple,
    this.compact = false,
    this.fontSize = 15,
    this.selectable = true,
    this.onTapLink,
    this.imageBuilder,
    this.editingPreferences,
    this.preferences = const MarkdownPreferences(),
    this.labels = const MarkdownEditorLabels(),
    this.onMediaContext,
    this.inline = false,
    this.documentSource,
    this.bodyStyle,
    this.inlineAlignment = WrapAlignment.start,
  });
  final String data;
  final MarkdownTypography typography;
  final bool compact, selectable;
  final double fontSize;
  final MarkdownEditingPreferences? editingPreferences;
  final MarkdownPreferences preferences;
  final MarkdownEditorLabels labels;
  final void Function(String text, String? href, String title)? onTapLink;
  final Widget Function(Uri uri, String? title, String? alt)? imageBuilder;
  final MarkdownMediaContextCallback? onMediaContext;
  final bool inline;

  /// Full document source used when this reader is rendering a block slice.
  /// It is needed by [TOC], whose entries may appear after the current block.
  final String? documentSource;
  final TextStyle? bodyStyle;
  final WrapAlignment inlineAlignment;
  MarkdownStyleSheet styleSheet(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = typography.accent(colors.brightness);
    final fonts = MarkdownFontFamilies.of(context);
    final font = editingPreferences?.font ?? MarkdownBodyFont.system;
    final book =
        font == MarkdownBodyFont.serif ||
        (font == MarkdownBodyFont.system && typography.serif);
    final mono = font == MarkdownBodyFont.mono;
    final body = Theme.of(context).textTheme.bodyMedium!
        .copyWith(
          fontSize: compact ? fontSize * .93 : fontSize,
          height: compact
              ? 1.65
              : typography == MarkdownTypography.book ||
                    typography == MarkdownTypography.journal
              ? 2.05
              : switch (typography) {
                  MarkdownTypography.document ||
                  MarkdownTypography.technical => 1.85,
                  MarkdownTypography.column => 1.95,
                  MarkdownTypography.editorial => 2,
                  _ => 1.9,
                },
          letterSpacing: 0,
          color: colors.onSurface,
          fontFamily: mono
              ? fonts.monospace
              : book
              ? fonts.serif
              : null,
          fontFamilyFallback: mono
              ? fonts.monospaceFallback
              : book
              ? fonts.serifFallback
              : null,
        )
        .merge(bodyStyle);
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: body,
      em: fonts.emphasis(body),
      pPadding: inline
          ? EdgeInsets.zero
          : EdgeInsets.only(bottom: compact ? 9 : fontSize, right: 3),
      textAlign: inlineAlignment,
      blockSpacing: 0,
      h1: body.copyWith(
        color: typography == MarkdownTypography.journal ? accent : null,
        fontSize:
            fontSize * (typography == MarkdownTypography.column ? 2.5 : 2),
        height: typography == MarkdownTypography.column
            ? 1.4
            : typography == MarkdownTypography.editorial
            ? 1.6
            : 1.45,
        fontWeight: typography == MarkdownTypography.column
            ? FontWeight.w800
            : typography == MarkdownTypography.book
            ? FontWeight.w600
            : FontWeight.w700,
        letterSpacing: 0,
      ),
      h1Padding: EdgeInsets.zero,
      h2: body.copyWith(
        fontSize: fontSize * 1.4,
        height: 1.6,
        fontWeight: FontWeight.w600,
        color: typography == MarkdownTypography.handbook
            ? colors.surface
            : typography == MarkdownTypography.simple ||
                  typography == MarkdownTypography.book ||
                  typography == MarkdownTypography.academic
            ? colors.onSurface
            : accent,
      ),
      h2Padding: EdgeInsets.zero,
      h3: body.copyWith(
        fontSize: fontSize * 1.15,
        height: 1.65,
        fontWeight: FontWeight.w600,
      ),
      h3Padding: EdgeInsets.zero,
      h4: body.copyWith(
        fontWeight: FontWeight.w600,
        fontStyle: typography == MarkdownTypography.academic
            ? FontStyle.italic
            : null,
        color: typography == MarkdownTypography.handbook ? accent : null,
      ),
      h5: body.copyWith(fontWeight: FontWeight.w600),
      h6: body.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.onSurfaceVariant,
      ),
      listBullet: body.copyWith(color: accent),
      checkbox: body.copyWith(color: colors.primary),
      listIndent: 24,
      listBulletPadding: const EdgeInsets.only(right: 8),
      blockquote: body.copyWith(color: colors.onSurfaceVariant),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
      ),
      code: TextStyle(
        fontFamily: fonts.monospace,
        fontFamilyFallback: fonts.monospaceFallback,
        fontSize: (body.fontSize ?? fontSize) * .87,
        height: 1.8,
        letterSpacing: 0,
        color: accent,
        backgroundColor: colors.surfaceContainerLow,
      ),
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(),
      a: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
      tableBorder: TableBorder.all(color: colors.outlineVariant),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      tableHead: body.copyWith(fontWeight: FontWeight.w600),
      tableBody: body,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheet = styleSheet(context);
    final imageOccurrences = <String, int>{};
    final linkOccurrences = <String, int>{};
    final body = _LinkRecognizerHost(
      reader: this,
      builder: (links) => MarkdownBody(
        key: ValueKey((
          preferences,
          onMediaContext != null,
          selectable,
          inline,
        )),
        data: data,
        // Render paragraphs directly. Per-paragraph EditableText viewports can
        // remain blank when their virtualized parent jumps to a distant block.
        selectable: false,
        fitContent: !inline,
        softLineBreak: preferences.softBreak,
        extensionSet: MarkdownSyntax.extensions(preferences),
        blockSyntaxes: inline
            ? const [MarkdownInlineBlockSyntax()]
            : MarkdownSyntax.blocks(preferences),
        inlineSyntaxes: MarkdownSyntax.inlines(preferences),
        styleSheet: sheet,
        onTapLink: onTapLink,
        imageBuilder: imageBuilder == null || onMediaContext == null
            ? imageBuilder
            : (uri, title, alt) {
                final url = uri.toString();
                final occurrence = imageOccurrences.update(
                  url,
                  (value) => value + 1,
                  ifAbsent: () => 0,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapUp: (event) => onMediaContext!(
                    url,
                    true,
                    occurrence,
                    event.globalPosition,
                  ),
                  onLongPressStart: (event) => onMediaContext!(
                    url,
                    true,
                    occurrence,
                    event.globalPosition,
                  ),
                  child: imageBuilder!(uri, title, alt),
                );
              },
        builders: {
          // The renderer probes every builder once before traversing each AST.
          // Reset counters even when inherited theme/text scale reparses it.
          'vex-parse-boundary': _ReaderParseBoundary(() {
            imageOccurrences.clear();
            linkOccurrences.clear();
          }),
          if (onMediaContext != null)
            'a': _ContextLinkBuilder(sheet, links, linkOccurrences),
          'pre': _CodeBlockBuilder(
            selectable,
            fontSize / 15 * (compact ? 13 : 14),
            editingPreferences,
            labels,
            preferences,
          ),
          'vex-math': _MathBuilder(this, false),
          'vex-math-block': _MathBuilder(this, true),
          for (final tag in ['mark', 'sub', 'sup'])
            tag: _InlineMarkBuilder(this, tag),
          'vex-toc': _TableOfContentsBuilder(this),
          'vex-callout': _CalloutBuilder(this),
          'vex-footnote': _FootnoteDefinitionBuilder(this),
          'vex-footnote-ref': _FootnoteReferenceBuilder(this),
          for (var level = 1; level <= 6; level++)
            'h$level': _HeadingBuilder(this, level, switch (level) {
              1 => sheet.h1!,
              2 => sheet.h2!,
              3 => sheet.h3!,
              4 => sheet.h4!,
              5 => sheet.h5!,
              _ => sheet.h6!,
            }, MarkdownFontFamilies.of(context)),
        },
      ),
    );
    return selectable && SelectionContainer.maybeOf(context) == null
        ? SelectionArea(child: body)
        : body;
  }
}

final class _TableOfContentsBuilder extends MarkdownElementBuilder {
  _TableOfContentsBuilder(this.reader);
  final MarkdownReader reader;

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final source = reader.documentSource ?? reader.data;
    final document = MarkdownDocument.parse(source);
    final anchors = markdownHeadingAnchors(
      document,
      preferences: reader.preferences,
    );
    final style = (parentStyle ?? reader.styleSheet(context).p!).copyWith(
      color: Theme.of(context).colorScheme.primary,
    );
    final entries = <Widget>[];
    for (final heading in document.headings) {
      final id = anchors.entries
          .where((entry) => identical(entry.value, heading))
          .map((entry) => entry.key)
          .firstOrNull;
      if (id == null) continue;
      entries.add(
        Padding(
          padding: EdgeInsets.only(left: (heading.level - 1) * 18.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: reader.onTapLink == null
                  ? null
                  : () => reader.onTapLink!(heading.title, '#$id', ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(heading.title, style: style),
              ),
            ),
          ),
        ),
      );
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    // 与原型一致：目录带“目录”标题与 1px 描边的提示框样式。
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              reader.labels.tocTitle,
              style: style.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...entries,
        ],
      ),
    );
  }
}

final class _CalloutBuilder extends MarkdownElementBuilder {
  _CalloutBuilder(this.reader);
  final MarkdownReader reader;

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colors = Theme.of(context).colorScheme;
    final warning = element.attributes['data-kind'] == 'warning';
    // 警告色与原型 --warning 一致（浅色琥珀深色亮黄），不用错误红。
    final accent = warning
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFFBBF24)
              : const Color(0xFFB54708))
        : colors.primary;
    final title = warning
        ? reader.labels.calloutWarning
        : reader.labels.calloutInfo;
    final body = (parentStyle ?? reader.styleSheet(context).p!).copyWith(
      color: colors.onSurface,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: body.copyWith(fontWeight: FontWeight.w700, color: accent),
          ),
          const SizedBox(height: 4),
          Text(element.textContent, style: body),
        ],
      ),
    );
  }
}

String _footnoteHref(String prefix, String label) =>
    '#$prefix${Uri.encodeComponent(label)}';

final class _FootnoteReferenceBuilder extends MarkdownElementBuilder {
  _FootnoteReferenceBuilder(this.reader);
  final MarkdownReader reader;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final label = element.attributes['data-label'] ?? element.textContent;
    final style = (parentStyle ?? reader.styleSheet(context).p!).copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontSize: (parentStyle?.fontSize ?? reader.fontSize) * .8,
    );
    return GestureDetector(
      onTap: reader.onTapLink == null
          ? null
          : () => reader.onTapLink!(
              '[$label]',
              _footnoteHref('vex-footnote-', label),
              '',
            ),
      child: Text('[$label]', style: style),
    );
  }
}

final class _FootnoteDefinitionBuilder extends MarkdownElementBuilder {
  _FootnoteDefinitionBuilder(this.reader);
  final MarkdownReader reader;

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final label = element.attributes['data-label'] ?? '';
    final style = parentStyle ?? reader.styleSheet(context).p!;
    return Container(
      key: ValueKey('vex-footnote-$label'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 5,
        children: [
          Text('[$label] ', style: style.copyWith(fontWeight: FontWeight.w700)),
          Text(element.textContent, style: style),
          GestureDetector(
            onTap: reader.onTapLink == null
                ? null
                : () => reader.onTapLink!(
                    '返回正文',
                    _footnoteHref('vex-footnote-ref-', label),
                    '',
                  ),
            child: Text(
              '↩',
              style: style.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextLinkBuilder extends MarkdownElementBuilder {
  _ContextLinkBuilder(this.sheet, this.links, this._occurrences);
  final MarkdownStyleSheet sheet;
  final _LinkRecognizerHostState links;
  final Map<String, int> _occurrences;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final url = markdownAttributeText(element.attributes['href'] ?? '');
    final occurrence = _occurrences.update(
      url,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    bool containsImage(md.Node node) =>
        node is md.Element &&
        (node.tag == 'img' || (node.children?.any(containsImage) ?? false));
    if (containsImage(element)) return null;
    final recognizer = links.recognizer(
      url,
      occurrence,
      element.textContent,
      element.attributes['title'] ?? '',
    );
    Iterable<TextSpan> spans(md.Node node, TextStyle style) sync* {
      if (node is md.Element) {
        final childStyle = style.merge(switch (node.tag) {
          'strong' => sheet.strong,
          'em' => sheet.em,
          'del' => sheet.del,
          'code' => sheet.code,
          _ => null,
        });
        if (node.tag == 'br') {
          yield TextSpan(text: '\n', style: childStyle, recognizer: recognizer);
        }
        for (final child in node.children ?? <md.Node>[]) {
          yield* spans(child, childStyle);
        }
        return;
      }
      yield TextSpan(
        text: node.textContent,
        style: style,
        recognizer: recognizer,
      );
    }

    final style = (parentStyle ?? sheet.p!).merge(sheet.a);
    return Text.rich(
      TextSpan(
        children: element.children
            ?.expand((node) => spans(node, style))
            .toList(),
      ),
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder(
    this.selectable,
    this.fontSize,
    this.preferences,
    this.labels,
    this.markdownPreferences,
  );
  final bool selectable;
  final double fontSize;
  final MarkdownEditingPreferences? preferences;
  final MarkdownEditorLabels labels;
  final MarkdownPreferences markdownPreferences;

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    if (markdownPreferences.mermaid &&
        code?.attributes['class']?.split(' ').contains('language-mermaid') ==
            true) {
      return MarkdownMermaidBlock(
        source: element.textContent.replaceFirst(RegExp(r'\n$'), ''),
        labels: labels,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: MarkdownCodeBlock(
        language:
            code?.attributes['class']?.replaceFirst('language-', '') ?? '',
        code: element.textContent.replaceFirst(RegExp(r'\n$'), ''),
        selectable: selectable,
        fontSize: preferences?.codeSize ?? fontSize,
        wrap: preferences?.codeWrap ?? false,
      ),
    );
  }
}

final class _MathBuilder extends MarkdownElementBuilder {
  _MathBuilder(this.reader, this.display);
  final MarkdownReader reader;
  final bool display;
  @override
  bool isBlockElement() => display;
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Padding(
    padding: display
        ? const EdgeInsets.symmetric(vertical: 18)
        : EdgeInsets.zero,
    child: MarkdownMathFormula(
      source: element.attributes['data-tex']!,
      display: display,
      fontSize: parentStyle?.fontSize ?? reader.fontSize,
      preferences: reader.preferences,
      fallback: element.textContent,
    ),
  );
}

final class _InlineMarkBuilder extends MarkdownElementBuilder {
  _InlineMarkBuilder(this.reader, this.tag);
  final MarkdownReader reader;
  final String tag;
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final c = Theme.of(context).colorScheme;
    final style = parentStyle ?? reader.styleSheet(context).p!;
    if (tag == 'mark') {
      return Text(
        element.textContent,
        style: style.copyWith(
          backgroundColor: c.brightness == Brightness.dark
              ? const Color(0xff685b28)
              : const Color(0xffffe49b),
        ),
      );
    }
    return Transform.translate(
      offset: Offset(0, tag == 'sup' ? -4 : 3),
      child: Text(
        element.textContent,
        style: style.copyWith(
          fontSize: (style.fontSize ?? reader.fontSize) * .75,
        ),
      ),
    );
  }
}

/// The same frame surrounds a heading in display and editing states.
class MarkdownHeadingFrame extends StatelessWidget {
  const MarkdownHeadingFrame({
    super.key,
    required this.typography,
    required this.level,
    required this.style,
    required this.child,
    this.compact = false,
  });
  final MarkdownTypography typography;
  final int level;
  final TextStyle style;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = typography.accent(colors.brightness);
    final size = style.fontSize!;
    final decorated =
        level == 2 &&
        typography != MarkdownTypography.simple &&
        typography != MarkdownTypography.book;
    final technical = decorated && typography == MarkdownTypography.technical;
    final column = decorated && typography == MarkdownTypography.column;
    final editorial = typography == MarkdownTypography.editorial;
    final handbook = typography == MarkdownTypography.handbook;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        top: level == 1
            ? 0
            : size *
                  (compact
                      ? 1.3
                      : level == 2
                      ? 1.4
                      : 1.15),
        bottom:
            size *
            (level == 1
                ? .55
                : level == 2
                ? .45
                : .35),
      ),
      padding: EdgeInsets.only(
        top: technical || (decorated && editorial) || (handbook && level <= 2)
            ? size * .45
            : 0,
        bottom: level == 1
            ? 0
            : technical || (decorated && editorial) || (handbook && level == 2)
            ? size * .45
            : decorated && !column
            ? size * .45
            : 0,
        left: technical || column || (handbook && level == 2) ? size * .65 : 0,
        right: technical || (handbook && level == 2) ? size * .65 : 0,
      ),
      decoration: BoxDecoration(
        color: handbook && level == 2
            ? accent
            : technical
            ? accent.withValues(alpha: .08)
            : null,
        border: handbook && level == 1
            ? Border(top: BorderSide(color: accent, width: 5))
            : handbook && level == 3
            ? Border(bottom: BorderSide(color: accent, width: 2))
            : decorated
            ? switch (typography) {
                MarkdownTypography.column ||
                MarkdownTypography.technical => Border(
                  left: BorderSide(color: accent, width: column ? 4 : 3),
                ),
                MarkdownTypography.editorial => Border.symmetric(
                  horizontal: BorderSide(color: colors.outlineVariant),
                ),
                MarkdownTypography.journal => Border(
                  bottom: BorderSide(color: accent),
                ),
                MarkdownTypography.academic => null,
                _ => Border(bottom: BorderSide(color: colors.outlineVariant)),
              }
            : null,
      ),
      child: child,
    );
  }
}

class _HeadingBuilder extends MarkdownElementBuilder {
  _HeadingBuilder(this.reader, this.level, this.style, this.fonts);
  final MarkdownReader reader;
  final int level;
  final TextStyle style;
  final MarkdownFontFamilies fonts;
  @override
  bool isBlockElement() => true;
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) =>
      MarkdownHeadingFrame(
        typography: reader.typography,
        compact: reader.compact,
        level: level,
        style: style,
        child: Padding(
          // RenderEditable reserves 1 px plus its 2 px caret. Keep the display
          // line width identical, including centred and wrapped headings.
          padding: const EdgeInsets.only(right: 3),
          child: Text.rich(
            TextSpan(children: _headingSpans(element.children ?? [], style)),
            style: style,
            textAlign: reader.typography.centered
                ? TextAlign.center
                : TextAlign.start,
          ),
        ),
      );

  List<InlineSpan> _headingSpans(List<md.Node> nodes, TextStyle style) => [
    for (final node in nodes)
      if (node is! md.Element)
        TextSpan(text: node.textContent, style: style)
      else if (node.tag == 'vex-math' || node.tag == 'vex-math-block')
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MarkdownMathFormula(
            source: node.attributes['data-tex']!,
            fontSize: style.fontSize ?? reader.fontSize,
            preferences: reader.preferences,
            fallback: node.textContent,
          ),
        )
      else if (node.tag == 'sub' || node.tag == 'sup')
        WidgetSpan(
          child: Transform.translate(
            offset: Offset(0, node.tag == 'sup' ? -5 : 3),
            child: Text(
              node.textContent,
              style: style.copyWith(fontSize: style.fontSize! * .75),
            ),
          ),
        )
      else
        TextSpan(
          style: style,
          children: _headingSpans(
            node.children ?? [],
            style
                .merge(node.tag == 'em' ? fonts.emphasis(style) : null)
                .copyWith(
                  fontWeight: node.tag == 'strong'
                      ? FontWeight.w700
                      : style.fontWeight,
                  decoration: node.tag == 'del'
                      ? TextDecoration.lineThrough
                      : style.decoration,
                  backgroundColor: node.tag == 'mark'
                      ? const Color(0xffffe49b)
                      : style.backgroundColor,
                ),
          ),
        ),
  ];
}
