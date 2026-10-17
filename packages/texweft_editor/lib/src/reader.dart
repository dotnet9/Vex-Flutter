import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'code_block.dart';
import 'font_families.dart';

enum MarkdownTypography {
  simple('简约', '日常写作 · 清爽留白'),
  document('文档', '知识整理 · 清晰分节'),
  book('书卷', '散文长读 · 衬线字形'),
  technical('技术', '开发笔记 · 信息模块'),
  column('专栏', '观点文章 · 鲜明层次'),
  editorial('刊物', '发布阅读 · 窄栏节奏');

  const MarkdownTypography(this.label, this.description);
  final String label, description;
  double get width => switch (this) {
    book => 800,
    technical => 1040,
    column => 880,
    editorial => 720,
    _ => 960,
  };
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
  });
  final String data;
  final MarkdownTypography typography;
  final bool compact, selectable;
  final double fontSize;
  final void Function(String text, String? href, String title)? onTapLink;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = typography == MarkdownTypography.column
        ? (colors.brightness == Brightness.dark
              ? const Color(0xffeba88d)
              : const Color(0xffa04d35))
        : colors.primary;
    final fonts = MarkdownFontFamilies.of(context);
    final book = typography == MarkdownTypography.book;
    final body = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: compact ? fontSize * .93 : fontSize,
      height: compact
          ? 1.65
          : typography == MarkdownTypography.book
          ? 2.05
          : 1.95,
      color: colors.onSurface,
      fontFamily: book ? fonts.serif : null,
      fontFamilyFallback: book ? fonts.serifFallback : null,
    );
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: body,
      pPadding: EdgeInsets.only(bottom: compact ? 9 : 16),
      h1: body.copyWith(
        fontSize:
            fontSize * (typography == MarkdownTypography.column ? 2.5 : 2),
        height: 1.45,
        fontWeight: FontWeight.w700,
      ),
      h1Padding: const EdgeInsets.only(top: 2, bottom: 26),
      h2: body.copyWith(
        fontSize: fontSize * 1.4,
        height: 1.6,
        fontWeight: FontWeight.w600,
        color:
            typography == MarkdownTypography.simple ||
                typography == MarkdownTypography.book
            ? colors.onSurface
            : accent,
      ),
      h2Padding: EdgeInsets.only(top: compact ? 17 : 30, bottom: 12),
      h3: body.copyWith(
        fontSize: fontSize * 1.15,
        height: 1.65,
        fontWeight: FontWeight.w600,
      ),
      h3Padding: EdgeInsets.only(top: compact ? 13 : 22, bottom: 10),
      h4: body.copyWith(fontWeight: FontWeight.w600),
      listBullet: body.copyWith(color: accent),
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
        fontSize: fontSize * .87,
        height: 1.8,
        color: accent,
        backgroundColor: colors.surfaceContainerLow,
      ),
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(),
      a: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
      tableBorder: TableBorder.all(color: colors.outlineVariant),
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
    return MarkdownBody(
      data: data,
      selectable: selectable,
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: sheet,
      onTapLink: onTapLink,
      builders: {
        'pre': _CodeBlockBuilder(selectable, compact ? 13 : 14),
        if (typography != MarkdownTypography.simple &&
            typography != MarkdownTypography.book)
          'h2': _SectionBuilder(
            typography,
            sheet.h2!,
            accent,
            colors.outlineVariant,
          ),
      },
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder(this.selectable, this.fontSize);
  final bool selectable;
  final double fontSize;

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => MarkdownCodeBlock(
    code: element.textContent.replaceFirst(RegExp(r'\n$'), ''),
    selectable: selectable,
    fontSize: fontSize,
  );
}

class _SectionBuilder extends MarkdownElementBuilder {
  _SectionBuilder(this.typography, this.style, this.accent, this.line);
  final MarkdownTypography typography;
  final TextStyle style;
  final Color accent, line;
  @override
  bool isBlockElement() => true;
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final editorial = typography == MarkdownTypography.editorial;
    final technical = typography == MarkdownTypography.technical;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 26, bottom: 12),
      padding: EdgeInsets.symmetric(
        vertical: technical || editorial ? 7 : 2,
        horizontal: technical || typography == MarkdownTypography.column
            ? 12
            : 0,
      ),
      decoration: BoxDecoration(
        color: technical ? accent.withValues(alpha: .08) : null,
        border: switch (typography) {
          MarkdownTypography.column || MarkdownTypography.technical => Border(
            left: BorderSide(color: accent, width: 3),
          ),
          MarkdownTypography.editorial => Border.symmetric(
            horizontal: BorderSide(color: line),
          ),
          _ => Border(bottom: BorderSide(color: line)),
        },
      ),
      child: Text(
        element.textContent,
        style: style,
        textAlign: editorial ? TextAlign.center : TextAlign.start,
      ),
    );
  }
}
