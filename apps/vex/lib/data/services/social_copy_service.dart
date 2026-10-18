import 'dart:convert';

import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart' as css;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:vex_editor/vex_editor.dart';

import 'export_service.dart';

enum PublishingPlatform { wechat, zhihu, juejin }

final class PublishingContent {
  const PublishingContent({required this.text, this.html});
  final String text;
  final String? html;
}

/// Produces clipboard content without changing the open document or its theme.
final class SocialCopyService {
  SocialCopyService({DocumentExportService? exporter})
    : _exporter = exporter ?? DocumentExportService();
  final DocumentExportService _exporter;
  static const _channel = MethodChannel('vex/clipboard');

  static String _css(css.TreeNode node) {
    final printer = css.CssPrinter();
    node.visit(printer);
    return printer.toString();
  }

  Future<PublishingContent> prepare({
    required PublishingPlatform platform,
    required String source,
    required String title,
    required MarkdownTypography typography,
    String? documentPath,
    bool compact = false,
    MarkdownPreferences markdown = const MarkdownPreferences(),
  }) async {
    if (platform == PublishingPlatform.juejin) {
      return PublishingContent(text: source);
    }
    final exported = await _exporter.html(
      source: source,
      title: title,
      documentPath: documentPath,
      colors: ColorScheme.fromSeed(seedColor: const Color(0xff24766b))
          .copyWith(surface: Colors.white, onSurface: const Color(0xff30343b)),
      typography: platform == PublishingPlatform.wechat
          ? typography
          : MarkdownTypography.simple,
      compact: platform == PublishingPlatform.wechat && compact,
      markdown: markdown,
    );
    return inlineArticle(exported);
  }

  static Future<void> write(PublishingContent content) async {
    if (content.html == null) {
      await Clipboard.setData(ClipboardData(text: content.text));
      return;
    }
    // Windows applications expect CF_HTML byte offsets, not a bare HTML string.
    for (var attempt = 0; ; attempt++) {
      try {
        await _channel.invokeMethod<void>('writeHtml', {
          'html': content.html,
          'text': content.text,
          'windowsHtml': windowsHtml(content.html!),
        });
        return;
      } on PlatformException catch (error) {
        if (error.code != 'clipboard_busy' || attempt >= 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
  }

  static Uint8List windowsHtml(String fragment) {
    const start = '<html><body><!--StartFragment-->';
    const end = '<!--EndFragment--></body></html>';
    String header(int a, int b, int c, int d) =>
        'Version:1.0\r\nStartHTML:${a.toString().padLeft(10, '0')}\r\n'
        'EndHTML:${b.toString().padLeft(10, '0')}\r\n'
        'StartFragment:${c.toString().padLeft(10, '0')}\r\n'
        'EndFragment:${d.toString().padLeft(10, '0')}\r\n';
    final offset = utf8.encode(header(0, 0, 0, 0)).length;
    final from = offset + utf8.encode(start).length;
    final to = from + utf8.encode(fragment).length;
    return Uint8List.fromList(
      utf8.encode(
        header(offset, to + utf8.encode(end).length, from, to) +
            start +
            fragment +
            end,
      ),
    );
  }

  /// Inline only the exporter's screen rules, preserving CSS cascade order.
  /// Publishing editors usually strip style sheets, scripts and class names.
  static PublishingContent inlineArticle(String source) {
    final document = html.parse(source);
    final rules = <({String selector, int rank, int order, String style})>[];
    var order = 0;
    for (final sheet in document.head!.querySelectorAll('style')) {
      for (final rule
          in css.parse(sheet.text).topLevels.whereType<css.RuleSet>()) {
        for (final selector in rule.selectorGroup!.selectors) {
          var rank = 0;
          for (final sequence in selector.simpleSelectorSequences) {
            final part = sequence.simpleSelector;
            rank += part is css.IdSelector
                ? 10000
                : part is css.ClassSelector || part is css.AttributeSelector
                ? 100
                : part is css.ElementSelector && !part.isWildcard
                ? 1
                : 0;
          }
          for (final declaration
              in rule.declarationGroup.declarations
                  .whereType<css.Declaration>()) {
            rules.add((
              selector: _css(selector),
              rank: rank + (declaration.important ? 1000000 : 0),
              order: order++,
              style:
                  '${declaration.property}:${_css(declaration.expression!)}'
                  '${declaration.important ? '!important' : ''};',
            ));
          }
        }
      }
    }
    rules.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      return byRank != 0 ? byRank : a.order.compareTo(b.order);
    });
    final styles = <dom.Element, StringBuffer>{};
    for (final element in document.querySelectorAll('*')) {
      styles[element] = StringBuffer();
    }
    for (final rule in rules) {
      for (final element in document.querySelectorAll(rule.selector)) {
        styles[element]!.write(rule.style);
      }
    }
    for (final element in document.querySelectorAll('*')) {
      final buffer = styles[element]!;
      // Existing inline declarations describe formula/image dimensions.
      final inline = css.parse('*{${element.attributes['style'] ?? ''}}');
      for (final rule in inline.topLevels.whereType<css.RuleSet>()) {
        for (final declaration
            in rule.declarationGroup.declarations
                .whereType<css.Declaration>()) {
          final value = declaration.expression == null
              ? ''
              : _css(declaration.expression!);
          if (const {
                'width',
                'height',
                'max-width',
                'color',
                'background-color',
                'font-family',
                'font-size',
                'font-weight',
                'font-style',
                'line-height',
                'text-align',
                'text-indent',
                'text-decoration',
                'white-space',
                'vertical-align',
                'padding',
                'margin',
                'border',
                'border-radius',
              }.contains(declaration.property) &&
              !value.toLowerCase().contains('url(') &&
              !value.toLowerCase().contains('expression(') &&
              !value.contains('\\')) {
            buffer.write('${declaration.property}:$value;');
          }
        }
      }
      element.attributes['style'] = buffer.toString();
    }
    final original = document.querySelector('article')!;
    final article = dom.Element.tag('section')
      ..attributes.addAll(original.attributes)
      ..nodes.addAll(original.nodes.toList());
    final bodyStyle = document.body!.attributes['style'] ?? '';
    article.attributes['style'] =
        '$bodyStyle;${article.attributes['style']};margin:0;padding:0;'
        'max-width:100%;';
    article
        .querySelectorAll(
          'script,style,iframe,object,embed,link,button,input,textarea,form',
        )
        .forEach((element) => element.remove());
    for (final element in [article, ...article.querySelectorAll('*')]) {
      if (!const {
        'section',
        'p',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'br',
        'hr',
        'div',
        'span',
        'strong',
        'em',
        'del',
        's',
        'sup',
        'sub',
        'mark',
        'code',
        'pre',
        'blockquote',
        'a',
        'img',
        'ul',
        'ol',
        'li',
        'table',
        'thead',
        'tbody',
        'tr',
        'th',
        'td',
        'tfoot',
        'dl',
        'dt',
        'dd',
      }.contains(element.localName)) {
        element.replaceWith(dom.Text(element.text));
        continue;
      }
      element.attributes.removeWhere(
        (key, value) => !const {
          'style',
          'href',
          'src',
          'alt',
          'title',
          'colspan',
          'rowspan',
          'start',
        }.contains(key),
      );
      final href = element.attributes['href'];
      if (href != null &&
          !href.startsWith('#') &&
          !const [
            'https',
            'http',
            'mailto',
          ].contains(Uri.tryParse(href)?.scheme)) {
        element.attributes.remove('href');
      }
      if (element.localName == 'img') {
        if (element.attributes['src']?.startsWith('data:image/') != true) {
          element.replaceWith(dom.Text(element.attributes['alt'] ?? 'Image'));
        } else {
          element.attributes['style'] =
              '${element.attributes['style']};max-width:100%;height:auto;';
        }
      }
    }
    final plain = StringBuffer();
    void text(dom.Node node) {
      if (node is dom.Text) {
        plain.write(node.data);
        return;
      }
      if (node is! dom.Element) return;
      if (node.localName == 'img') plain.write(node.attributes['alt'] ?? '');
      for (final child in node.nodes) {
        text(child);
      }
      if (const {
        'p',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'li',
        'pre',
        'br',
        'tr',
      }.contains(node.localName)) {
        plain.writeln();
      }
      if (node.localName == 'td' || node.localName == 'th') plain.write('\t');
    }

    text(article);
    return PublishingContent(
      text: plain.toString().trim(),
      html: article.outerHtml,
    );
  }
}
