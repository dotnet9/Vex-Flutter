import 'dart:convert';

import 'package:markdown/markdown.dart' as md;
import 'package:val_latex_flutter/val_latex_flutter.dart' as latex;

import 'markdown_preferences.dart';

/// Table cells accept inline Markdown, never headings, lists or fenced blocks.
final class MarkdownInlineBlockSyntax extends md.BlockSyntax {
  const MarkdownInlineBlockSyntax();
  @override
  RegExp get pattern => RegExp(r'.');
  @override
  md.Node parse(md.BlockParser parser) {
    final text = parser.current.content;
    parser.advance();
    return md.Element('p', [md.UnparsedContent(text)]);
  }
}

/// One syntax configuration for instant editing, reading and all encoders.
abstract final class MarkdownSyntax {
  static md.ExtensionSet extensions(MarkdownPreferences preferences) =>
      md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        md.ExtensionSet.gitHubFlavored.inlineSyntaxes
            .where(
              (s) =>
                  s is! md.InlineHtmlSyntax &&
                  s is! md.StrikethroughSyntax &&
                  (preferences.autoLink || s is! md.AutolinkExtensionSyntax),
            )
            .toList(),
      );

  static List<md.BlockSyntax> blocks(MarkdownPreferences preferences) => [
    const _TableOfContentsSyntax(),
    const _CalloutSyntax(),
    const _FootnoteDefinitionSyntax(),
    if (preferences.math || preferences.chemistry)
      _FormulaBlockSyntax(preferences),
  ];

  static List<md.InlineSyntax> inlines(MarkdownPreferences preferences) => [
    _FootnoteReferenceSyntax(),
    if (preferences.math || preferences.chemistry)
      _FormulaInlineSyntax(preferences),
    if (preferences.highlight) _TextMarkSyntax('mark', r'==([^=\n]+)=='),
    if (preferences.subscript) ...[
      _TextMarkSyntax('sub', r'(?<!~)~([^~\s]+)~(?!~)'),
      _TextMarkSyntax('sup', r'\^([^\^\s]+)\^'),
    ],
    _DoubleStrikethroughSyntax(),
    _SoftBreakSyntax(preferences.softBreak),
  ];

  static md.Element formula(latex.MathSegment segment, bool encodeHtml) =>
      md.Element.text(
        segment.display ? 'vex-math-block' : 'vex-math',
        encodeHtml
            ? const HtmlEscape().convert(
                '${segment.open}${segment.tex}${segment.close}',
              )
            : '${segment.open}${segment.tex}${segment.close}',
      )..attributes['data-tex'] = segment.tex;
}

final class _DoubleStrikethroughSyntax extends md.DelimiterSyntax {
  _DoubleStrikethroughSyntax()
    : super(
        '~+',
        requiresDelimiterRun: true,
        allowIntraWord: true,
        startCharacter: 126,
        tags: [md.DelimiterTag('del', 2)],
      );
}

final class _FormulaInlineSyntax extends md.InlineSyntax {
  _FormulaInlineSyntax(this.preferences) : super(r'[$\\]');
  final MarkdownPreferences preferences;
  final _segments = Expando<Map<int, latex.MathSegment>>();

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final position = startMatchPos ?? parser.pos;
    final code = parser.source.codeUnitAt(position);
    if (code != 36 && code != 92) return false;
    final segments = _segments[parser] ??= {
      for (final s in const latex.MathScanner(
        environments: false,
      ).scan(parser.source))
        if (s is latex.MathSegment && s.complete) s.span.start: s,
    };
    final segment = segments[position];
    if (segment == null ||
        segment.tex.length > 8192 ||
        !preferences.rendersFormula(segment.tex)) {
      return false;
    }
    parser.writeText();
    parser.addNode(MarkdownSyntax.formula(segment, parser.document.encodeHtml));
    parser.consume(segment.span.end - segment.span.start);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;
}

final class _FormulaBlockSyntax extends md.BlockSyntax {
  _FormulaBlockSyntax(this.preferences);
  final MarkdownPreferences preferences;
  @override
  RegExp get pattern => RegExp(r'^ {0,3}(?:\$\$|\\\[)');

  (latex.MathSegment, int)? _match(md.BlockParser parser) {
    if (!pattern.hasMatch(parser.current.content)) return null;
    final lines = <String>[];
    for (var i = 0; i < 256; i++) {
      final line = parser.peek(i);
      if (line == null) break;
      lines.add(line.content);
      final source = lines.join('\n');
      if (source.length > 8192) break;
      final segments = const latex.MathScanner(environments: false)
          .scan(source);
      if (segments.whereType<latex.MathSegment>().firstOrNull case final s?) {
        if (s.display &&
            s.complete &&
            source.substring(0, s.span.start).trim().isEmpty &&
            source.substring(s.span.end).trim().isEmpty &&
            preferences.rendersFormula(s.tex)) {
          return (s, i + 1);
        }
      }
    }
    return null;
  }

  @override
  bool canParse(md.BlockParser parser) => _match(parser) != null;
  @override
  md.Node parse(md.BlockParser parser) {
    final (segment, count) = _match(parser)!;
    for (var i = 0; i < count; i++) {
      parser.advance();
    }
    return MarkdownSyntax.formula(segment, parser.document.encodeHtml);
  }
}

/// A standalone [TOC] marker is rendered by the reader as a clickable
/// document outline. Keeping the marker as its own node also means it remains
/// editable in source mode.
final class _TableOfContentsSyntax extends md.BlockSyntax {
  const _TableOfContentsSyntax();
  @override
  RegExp get pattern => RegExp(r'^ {0,3}\[TOC\][ \t]*$');
  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    return md.Element.empty('vex-toc');
  }
}

/// GitHub-style callouts. The body is intentionally kept as text so a
/// partially written callout never causes the rest of a document to vanish.
final class _CalloutSyntax extends md.BlockSyntax {
  const _CalloutSyntax();
  @override
  RegExp get pattern => RegExp(r'^ {0,3}>[ \t]*\[!(INFO|WARNING)\][ \t]*(.*)$');
  @override
  md.Node parse(md.BlockParser parser) {
    final first = parser.current.content;
    final match = pattern.firstMatch(first)!;
    final kind = match[1]!.toLowerCase();
    // 与原型一致：标签行的同行文字从正文中剥离。
    final lines = <String>[];
    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      final body = RegExp(r'^ {0,3}>[ \t]?(.*)$').firstMatch(line);
      if (body == null) break;
      lines.add(body[1]!);
      parser.advance();
    }
    return md.Element.text('vex-callout', lines.join('\n'))
      ..attributes['data-kind'] = kind;
  }
}

/// A footnote definition is a block of its own, which lets the reader attach
/// a stable target and a return link without exposing the Markdown marker.
final class _FootnoteDefinitionSyntax extends md.BlockSyntax {
  const _FootnoteDefinitionSyntax();
  @override
  RegExp get pattern => RegExp(r'^ {0,3}\[\^([^\]\r\n]+)\]:[ \t]*(.*)$');
  @override
  md.Node parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    final label = match[1]!.trim();
    final lines = <String>[match[2]!];
    parser.advance();
    while (!parser.isDone) {
      final continuation = RegExp(r'^ {2,}(.*)$')
          .firstMatch(parser.current.content);
      if (continuation == null) break;
      lines.add(continuation[1]!);
      parser.advance();
    }
    return md.Element.text('vex-footnote', lines.join('\n'))
      ..attributes['data-label'] = label;
  }
}

final class _FootnoteReferenceSyntax extends md.InlineSyntax {
  _FootnoteReferenceSyntax() : super(r'\[\^([^\]\r\n]+)\]');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final label = match[1]!.trim();
    parser.addNode(
      md.Element.text('vex-footnote-ref', label)
        ..attributes['data-label'] = label,
    );
    return true;
  }
}

final class _TextMarkSyntax extends md.InlineSyntax {
  _TextMarkSyntax(this.tag, String pattern) : super(pattern);
  final String tag;
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final value = match[1]!;
    parser.addNode(
      md.Element.text(
        tag,
        parser.document.encodeHtml ? const HtmlEscape().convert(value) : value,
      ),
    );
    return true;
  }
}

final class _SoftBreakSyntax extends md.InlineSyntax {
  _SoftBreakSyntax(this.enabled) : super(r'\n');
  final bool enabled;
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(enabled ? md.Element.empty('br') : md.Text(' '));
    return true;
  }
}
