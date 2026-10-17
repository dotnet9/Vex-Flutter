import 'dart:convert';

import 'package:markdown/markdown.dart' as md;
import 'package:val_latex_flutter/val_latex_flutter.dart' as latex;

import 'markdown_preferences.dart';

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
    if (preferences.math || preferences.chemistry)
      _FormulaBlockSyntax(preferences),
  ];

  static List<md.InlineSyntax> inlines(MarkdownPreferences preferences) => [
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
