import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'code_block.dart';
import 'editing_preferences.dart';
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
    this.imageBuilder,
    this.editingPreferences,
  });
  final String data;
  final MarkdownTypography typography;
  final bool compact, selectable;
  final double fontSize;
  final MarkdownEditingPreferences? editingPreferences;
  final void Function(String text, String? href, String title)? onTapLink;
  final Widget Function(Uri uri, String? title, String? alt)? imageBuilder;
  MarkdownStyleSheet styleSheet(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = typography == MarkdownTypography.column
        ? (colors.brightness == Brightness.dark
              ? const Color(0xffeba88d)
              : const Color(0xffa04d35))
        : colors.primary;
    final fonts = MarkdownFontFamilies.of(context);
    final font = editingPreferences?.font ?? MarkdownBodyFont.system;
    final book =
        font == MarkdownBodyFont.serif ||
        (font == MarkdownBodyFont.system &&
            typography == MarkdownTypography.book);
    final mono = font == MarkdownBodyFont.mono;
    final body = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: compact ? fontSize * .93 : fontSize,
      height: compact
          ? 1.65
          : typography == MarkdownTypography.book
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
    );
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: body,
      pPadding: EdgeInsets.only(bottom: compact ? 9 : fontSize, right: 3),
      blockSpacing: 0,
      h1: body.copyWith(
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
        color:
            typography == MarkdownTypography.simple ||
                typography == MarkdownTypography.book
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
      h4: body.copyWith(fontWeight: FontWeight.w600),
      h5: body.copyWith(fontWeight: FontWeight.w600),
      h6: body.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.onSurfaceVariant,
      ),
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
  }

  @override
  Widget build(BuildContext context) {
    final sheet = styleSheet(context);
    return MarkdownBody(
      data: data,
      selectable: selectable,
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: sheet,
      onTapLink: onTapLink,
      imageBuilder: imageBuilder,
      builders: {
        'pre': _CodeBlockBuilder(
          selectable,
          fontSize / 15 * (compact ? 13 : 14),
          editingPreferences,
        ),
        for (var level = 1; level <= 6; level++)
          'h$level': _HeadingBuilder(this, level, switch (level) {
            1 => sheet.h1!,
            2 => sheet.h2!,
            3 => sheet.h3!,
            4 => sheet.h4!,
            5 => sheet.h5!,
            _ => sheet.h6!,
          }),
      },
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder(this.selectable, this.fontSize, this.preferences);
  final bool selectable;
  final double fontSize;
  final MarkdownEditingPreferences? preferences;

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: MarkdownCodeBlock(
      code: element.textContent.replaceFirst(RegExp(r'\n$'), ''),
      selectable: selectable,
      fontSize: preferences?.codeSize ?? fontSize,
      wrap: preferences?.codeWrap ?? false,
    ),
  );
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
    final accent = typography == MarkdownTypography.column
        ? (colors.brightness == Brightness.dark
              ? const Color(0xffeba88d)
              : const Color(0xffa04d35))
        : colors.primary;
    final size = style.fontSize!;
    final decorated =
        level == 2 &&
        typography != MarkdownTypography.simple &&
        typography != MarkdownTypography.book;
    final technical = decorated && typography == MarkdownTypography.technical;
    final column = decorated && typography == MarkdownTypography.column;
    final editorial = typography == MarkdownTypography.editorial;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        top: level == 1
            ? 0
            : size *
                  (compact
                      ? 1.3
                      : level == 2
                      ? 1.8
                      : 1.4),
        bottom:
            size *
            (level == 1
                ? (editorial ? 1.5 : 1)
                : level == 2
                ? .6
                : .5),
      ),
      padding: EdgeInsets.only(
        top: technical || (decorated && editorial) ? size * .45 : 0,
        bottom: level == 1
            ? size * .6
            : technical || (decorated && editorial)
            ? size * .45
            : decorated && !column
            ? size * .45
            : 0,
        left: technical || column ? size * .65 : 0,
        right: technical ? size * .65 : 0,
      ),
      decoration: BoxDecoration(
        color: technical ? accent.withValues(alpha: .08) : null,
        border: decorated
            ? switch (typography) {
                MarkdownTypography.column ||
                MarkdownTypography.technical => Border(
                  left: BorderSide(color: accent, width: column ? 4 : 3),
                ),
                MarkdownTypography.editorial => Border.symmetric(
                  horizontal: BorderSide(color: colors.outlineVariant),
                ),
                _ => Border(bottom: BorderSide(color: colors.outlineVariant)),
              }
            : null,
      ),
      child: child,
    );
  }
}

class _HeadingBuilder extends MarkdownElementBuilder {
  _HeadingBuilder(this.reader, this.level, this.style);
  final MarkdownReader reader;
  final int level;
  final TextStyle style;
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
          child: Text(
            element.textContent,
            style: style,
            textAlign: reader.typography == MarkdownTypography.editorial
                ? TextAlign.center
                : TextAlign.start,
          ),
        ),
      );
}
