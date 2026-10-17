import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:texweft_editor/texweft_editor.dart';
import 'package:texweft_mindmap/texweft_mindmap.dart';

import '../../domain/export_preferences.dart';
import 'export_images.dart';

/// Native document encoders. No browser engine or HTML-to-PDF WebView.
final class DocumentExportService {
  static List<md.Node> _parse(
    String source,
    MarkdownPreferences preferences, {
    bool encodeHtml = false,
    List<md.BlockSyntax> extraBlocks = const [],
  }) => md.Document(
    extensionSet: MarkdownSyntax.extensions(preferences),
    blockSyntaxes: [...MarkdownSyntax.blocks(preferences), ...extraBlocks],
    inlineSyntaxes: MarkdownSyntax.inlines(preferences),
    encodeHtml: encodeHtml,
  ).parseLines(source.split('\n'));
  static bool _formula(md.Node node) =>
      node is md.Element &&
      (node.tag == 'vex-math' || node.tag == 'vex-math-block');

  Future<Map<md.Node, ({ui.Size size, Uint8List bytes})>> _formulaImages(
    List<md.Node> nodes,
    MarkdownPreferences preferences,
    Color color,
  ) async {
    final images = <md.Node, ({ui.Size size, Uint8List bytes})>{};
    final cache = <(String, bool), ({ui.Size size, Uint8List bytes})>{};
    Future<void> collect(md.Node node) async {
      if (_formula(node)) {
        final element = node as md.Element;
        final key = (
          element.attributes['data-tex']!,
          element.tag == 'vex-math-block',
        );
        try {
          images[node] = cache[key] ??= await MarkdownMathRenderer.png(
            key.$1,
            display: key.$2,
            preferences: preferences,
            color: color,
          );
        } catch (_) {
          // Malformed TeX remains readable source, never a missing image.
        }
      } else if (node is md.Element) {
        for (final child in node.children ?? <md.Node>[]) {
          await collect(child);
        }
      }
    }

    for (final node in nodes) {
      await collect(node);
    }
    return images;
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
  static String _escape(String value) => const HtmlEscape().convert(value);
  static bool _mermaid(md.Node node) =>
      node is md.Element &&
      node.tag == 'pre' &&
      node.children?.whereType<md.Element>().any(
            (child) =>
                child.attributes['class']
                    ?.toLowerCase()
                    .split(' ')
                    .contains('language-mermaid') ==
                true,
          ) ==
          true;

  static Future<pw.Font> _pdfFont(String name) async {
    final packed = await rootBundle.load('assets/fonts/$name.ttf.z');
    final bytes = const ZLibDecoder().decodeBytes(packed.buffer.asUint8List());
    return pw.Font.ttf(ByteData.sublistView(bytes));
  }

  Future<String> html({
    required String source,
    required String title,
    required ColorScheme colors,
    required MarkdownTypography typography,
    String? documentPath,
    bool compact = false,
    bool styled = true,
    WatermarkPreferences watermark = const WatermarkPreferences(),
    MarkdownPreferences markdown = const MarkdownPreferences(),
  }) async {
    if (!styled) {
      typography = MarkdownTypography.simple;
      compact = false;
      colors = ColorScheme.fromSeed(seedColor: const Color(0xff24766b));
    }
    final accent = _hex(colors.primary),
        fg = _hex(colors.onSurface),
        bg = _hex(colors.surface),
        panel = _hex(colors.surfaceContainerLow),
        border = _hex(colors.outlineVariant);
    final section = switch (typography) {
      MarkdownTypography.document =>
        'border-bottom:1px solid $border;padding-bottom:10px',
      MarkdownTypography.technical =>
        'border-left:3px solid $accent;background:$panel;padding:8px 14px',
      MarkdownTypography.column =>
        'border-left:3px solid $accent;padding-left:14px',
      MarkdownTypography.editorial =>
        'border-block:1px solid $border;text-align:center;padding:9px 0',
      _ => '',
    };
    final parsed = _parse(
      source,
      markdown,
      encodeHtml: true,
      extraBlocks: [if (markdown.mermaid) _MermaidHtmlSyntax(colors)],
    );
    MarkdownHeadingIds().assign(parsed, encodedHtml: true);
    final formulas = await _formulaImages(parsed, markdown, colors.onSurface);
    final images = await ExportImages(documentPath: documentPath)
        .collect(parsed);
    md.Node resolve(md.Node node) {
      if (_formula(node)) {
        final image = formulas[node];
        if (image == null) return md.Text(node.textContent);
        final element = node as md.Element;
        return md.Element.empty('img')
          ..attributes.addAll({
            'src': 'data:image/png;base64,${base64Encode(image.bytes)}',
            'alt': _escape(element.attributes['data-tex']!),
            'class': element.tag == 'vex-math-block'
                ? 'vex-math-block'
                : 'vex-math',
            'style':
                'width:${image.size.width / 18}em;height:${image.size.height / 18}em',
          });
      }
      if (node is md.Element &&
          node.tag == 'img' &&
          node.attributes['class'] != 'vex-diagram') {
        final image = images[node];
        if (image == null) {
          return md.Element.text('span', node.attributes['alt'] ?? 'Image')
            ..attributes['class'] = 'vex-missing-image';
        }
        return md.Element.empty('img')
          ..attributes.addAll(node.attributes)
          ..attributes['src'] =
              'data:image/png;base64,${base64Encode(image.bytes)}'
          ..attributes['width'] = image.size.width.round().toString()
          ..attributes['height'] = image.size.height.round().toString();
      }
      if (node is md.Element && node.children != null) {
        return md.Element(node.tag, node.children!.map(resolve).toList())
          ..attributes.addAll(node.attributes)
          ..generatedId = node.generatedId
          ..footnoteLabel = node.footnoteLabel;
      }
      return node;
    }

    final body = md.renderToHtml(parsed.map(resolve).toList());
    return '''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src https: http: data: file:; font-src data:">
<title>${_escape(title)}</title><style>
*{box-sizing:border-box}body{margin:0;background:$bg;color:$fg;font:14px/${compact
        ? 1.65
        : typography == MarkdownTypography.book
        ? 2.05
        : 1.95} ${typography == MarkdownTypography.book ? 'Georgia,"Noto Serif CJK SC",SimSun,serif' : 'system-ui,"Microsoft YaHei UI","PingFang SC",sans-serif'}}
article{max-width:${typography.width.toInt()}px;margin:auto;padding:44px 48px 80px;overflow-wrap:anywhere}h1{font-size:2em;line-height:1.45;margin:0 0 30px}h2{font-size:1.4em;line-height:1.6;margin:32px 0 16px;$section}h3{font-size:1.15em;margin-top:26px}p{margin:0 0 ${compact ? 10 : 18}px}a{color:$accent}blockquote{margin:18px 0;padding:12px 18px;border-left:3px solid $accent;background:$panel}pre{white-space:pre;overflow-x:auto;padding:8px 12px;background:$panel;border:1px solid $border;border-radius:3px}pre code{font:14px/22px Consolas,Menlo,monospace;color:$fg;background:transparent}code{font:0.9em/1.8 Consolas,monospace;background:$panel}table{border-collapse:collapse;width:100%;margin:18px 0}td,th{border:1px solid $border;padding:9px 12px;text-align:left}th{background:$panel}img{max-width:100%}hr{border:0;border-top:1px solid $border;margin:28px 0}li{margin:6px 0}@media(max-width:600px){article{padding:28px 22px}}@media print{body{color:#222;background:white}article{padding:0;max-width:none}h1,h2,h3{break-after:avoid}pre,blockquote,tr{break-inside:avoid}}
.vex-watermark{position:fixed;inset:0;z-index:10;pointer-events:none;user-select:none;overflow:hidden}.vex-watermark svg{width:100%;height:100%;display:block}
img{height:auto}.vex-missing-image{display:inline-block;padding:8px 12px;border:1px dashed $border;color:$fg}.vex-math{vertical-align:middle;object-fit:contain;max-width:100%;height:auto!important}.vex-math-block{display:block;margin:20px auto;max-width:100%;height:auto!important;font-size:1.15em}mark{color:inherit;background:#ffe49b}
</style></head><body><article>$body</article>${watermark.export && watermark.visible ? _htmlWatermark(watermark.copyWith()) : ''}</body></html>''';
  }

  String _htmlWatermark(WatermarkPreferences watermark) =>
      '''<div class="vex-watermark" aria-hidden="true"><svg xmlns="http://www.w3.org/2000/svg"><defs><pattern id="vex-watermark" width="280" height="180" patternUnits="userSpaceOnUse"><text x="140" y="90" fill="#24766b" fill-opacity="${watermark.opacity}" text-anchor="middle" dominant-baseline="middle" font-family="system-ui,sans-serif" font-size="21" transform="rotate(-25 140 90)"${watermark.text.runes.length > 14 ? ' textLength="235" lengthAdjust="spacingAndGlyphs"' : ''}>${_escape(watermark.text)}</text></pattern></defs><rect width="100%" height="100%" fill="url(#vex-watermark)"/></svg></div>''';

  Future<Uint8List> pdf({
    required String source,
    required String title,
    required ColorScheme colors,
    required MarkdownTypography typography,
    String? documentPath,
    bool compact = false,
    ExportPreferences preferences = const ExportPreferences(),
    WatermarkPreferences watermark = const WatermarkPreferences(),
    MarkdownPreferences markdown = const MarkdownPreferences(),
  }) async {
    final font = await _pdfFont('NotoSansSC');
    final boldFont = await _pdfFont('NotoSansSC-SemiBold');
    final accent = PdfColor.fromInt(colors.primary.toARGB32()),
        line = PdfColor.fromInt(colors.outlineVariant.toARGB32());
    final document = pw.Document(title: title, author: 'Vex');
    final base = pw.TextStyle(
      font: font,
      fontSize: 10,
      lineSpacing: compact ? 3 : 5,
      color: PdfColors.grey900,
    );
    final format = switch (preferences.paper) {
      ExportPaper.a4 => PdfPageFormat.a4,
      ExportPaper.letter => PdfPageFormat.letter,
      ExportPaper.a5 => PdfPageFormat.a5,
    };
    final diagramColors = colors.brightness == Brightness.dark
        ? ColorScheme.fromSeed(seedColor: colors.primary)
        : colors;
    final parsed = _parse(source, markdown);
    final images = await ExportImages(documentPath: documentPath)
        .collect(parsed);
    final imageProviders = <ExportImage, pw.MemoryImage>{};
    for (final image in images.values) {
      imageProviders.putIfAbsent(image, () => pw.MemoryImage(image.bytes));
    }
    final contentWidth =
        format.width - 2 * preferences.margin.clamp(10, 30) * PdfPageFormat.mm;
    final imageHeight =
        format.height -
        2 * preferences.margin.clamp(10, 30) * PdfPageFormat.mm -
        100;
    final formulas = await _formulaImages(
      parsed,
      markdown,
      const Color(0xff222222),
    );
    pw.Widget paragraph(String text, {double size = 10, bool bold = false}) =>
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: compact ? 6 : 10),
          child: pw.Text(
            text,
            style: base.copyWith(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );
    List<pw.Widget> render(
      List<md.Node> nodes, {
      int depth = 0,
      bool groupDiagrams = true,
    }) {
      final result = <pw.Widget>[];
      for (var index = 0; index < nodes.length; index++) {
        final node = nodes[index];
        if (groupDiagrams &&
            node is md.Element &&
            RegExp(r'^h[1-6]$').hasMatch(node.tag) &&
            index + 1 < nodes.length &&
            _mermaid(nodes[index + 1])) {
          result.add(
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: render(
                  [node, nodes[++index]],
                  depth: depth,
                  groupDiagrams: false,
                ),
              ),
            ),
          );
          continue;
        }
        if (node is! md.Element) {
          if (node.textContent.trim().isNotEmpty) {
            result.add(paragraph(node.textContent));
          }
          continue;
        }
        final heading = RegExp(r'^h([1-6])$').firstMatch(node.tag);
        if (_formula(node)) {
          final image = formulas[node];
          result.add(
            image == null
                ? paragraph(node.textContent)
                : pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 12),
                    child: pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(image.bytes),
                        width: math.min(
                          image.size.width * 2 / 3,
                          format.width -
                              2 * preferences.margin * PdfPageFormat.mm,
                        ),
                        height: math.min(
                          image.size.height * 2 / 3,
                          format.height / 2,
                        ),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
          );
        } else if (heading != null) {
          final level = int.parse(heading[1]!);
          final headingStyle = base.copyWith(
            fontSize: level == 1
                ? 22
                : level == 2
                ? 15
                : 12,
            fontWeight: pw.FontWeight.bold,
            color: level == 2 && typography == MarkdownTypography.technical
                ? accent
                : PdfColors.grey900,
          );
          result.add(
            pw.Container(
              margin: pw.EdgeInsets.only(top: level == 1 ? 0 : 14, bottom: 8),
              padding: const pw.EdgeInsets.only(bottom: 5),
              decoration:
                  level == 2 &&
                      typography != MarkdownTypography.simple &&
                      typography != MarkdownTypography.book
                  ? pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: line)),
                    )
                  : null,
              child: pw.RichText(
                text: pw.TextSpan(
                  children: _pdfInline(
                    node.children ?? [],
                    headingStyle,
                    accent,
                    formulas: formulas,
                    images: images,
                    imageProviders: imageProviders,
                    imageWidth: contentWidth,
                    imageHeight: imageHeight,
                  ),
                  style: headingStyle,
                ),
              ),
            ),
          );
        } else if (node.tag == 'pre') {
          if (markdown.mermaid && _mermaid(node)) {
            try {
              final scene = MarkdownMermaidRenderer.scene(
                node.textContent,
                diagramColors,
              );
              final availableWidth =
                  format.width -
                  2 * preferences.margin.clamp(10, 30) * PdfPageFormat.mm;
              final height = math.min(
                format.height -
                    2 * preferences.margin.clamp(10, 30) * PdfPageFormat.mm -
                    120,
                availableWidth * scene.size.height / scene.size.width,
              );
              result.add(
                pw.Container(
                  width: availableWidth,
                  height: height,
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.SvgImage(
                    svg: MarkdownMermaidRenderer.svg(
                      node.textContent,
                      diagramColors,
                    ),
                    customFontLookup: (_, _, weight) =>
                        weight == 'bold' || weight == '700' ? boldFont : font,
                  ),
                ),
              );
              continue;
            } catch (_) {
              // Keep the source readable when the engine rejects a diagram.
            }
          }
          result.add(
            pw.Table(
              border: pw.TableBorder(
                top: pw.BorderSide(color: line),
                bottom: pw.BorderSide(color: line),
                left: pw.BorderSide(color: line),
                right: pw.BorderSide(color: line),
              ),
              columnWidths: const {0: pw.FlexColumnWidth()},
              children: [
                for (final codeLine
                    in node.textContent
                        .replaceFirst(RegExp(r'\n$'), '')
                        .split('\n'))
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        child: pw.Text(
                          codeLine.isEmpty ? ' ' : codeLine,
                          style: base.copyWith(
                            fontNormal: pw.Font.courier(),
                            fontFallback: [font],
                            fontSize: 9,
                            lineSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        } else if (node.tag == 'blockquote') {
          result.add(
            pw.Container(
              padding: const pw.EdgeInsets.only(left: 12),
              margin: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: accent, width: 2)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: render(node.children ?? [], depth: depth),
              ),
            ),
          );
        } else if (node.tag == 'ul' || node.tag == 'ol') {
          var index = int.tryParse(node.attributes['start'] ?? '1') ?? 1;
          for (final item in (node.children ?? []).whereType<md.Element>()) {
            result.add(
              pw.Padding(
                padding: pw.EdgeInsets.only(left: depth * 12, bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 18,
                      child: pw.Text(
                        node.tag == 'ol' ? '${index++}.' : '•',
                        style: base.copyWith(color: accent),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(
                          style: base,
                          children: _pdfInline(
                            item.children ?? [],
                            base,
                            accent,
                            formulas: formulas,
                            images: images,
                            imageProviders: imageProviders,
                            imageWidth: contentWidth - depth * 12 - 18,
                            imageHeight: imageHeight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          result.add(pw.SizedBox(height: 6));
        } else if (node.tag == 'table') {
          final rows = <List<md.Node>>[];
          void collect(md.Node n) {
            if (n is md.Element && n.tag == 'tr') {
              rows.add(n.children ?? []);
            } else if (n is md.Element) {
              for (final child in n.children ?? <md.Node>[]) {
                collect(child);
              }
            }
          }

          collect(node);
          if (rows.isNotEmpty) {
            result.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Table(
                  border: pw.TableBorder.all(color: line),
                  children: [
                    for (var row = 0; row < rows.length; row++)
                      pw.TableRow(
                        repeat: row == 0,
                        decoration: row == 0
                            ? const pw.BoxDecoration(color: PdfColors.grey100)
                            : null,
                        children: [
                          for (final cell in rows[row])
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.RichText(
                                text: pw.TextSpan(
                                  style: base,
                                  children: _pdfInline(
                                    [cell],
                                    base,
                                    accent,
                                    formulas: formulas,
                                    images: images,
                                    imageProviders: imageProviders,
                                    imageWidth:
                                        contentWidth / rows[row].length - 16,
                                    imageHeight: math.min(imageHeight, 250),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }
        } else if (node.tag == 'hr') {
          result.add(pw.Divider(color: line));
        } else {
          result.add(
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: compact ? 7 : 12),
              child: pw.RichText(
                text: pw.TextSpan(
                  style: base,
                  children: _pdfInline(
                    node.children ?? [md.Text(node.textContent)],
                    base,
                    accent,
                    formulas: formulas,
                    images: images,
                    imageProviders: imageProviders,
                    imageWidth: contentWidth - depth * 12,
                    imageHeight: imageHeight,
                  ),
                ),
              ),
            ),
          );
        }
      }
      return result;
    }

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          theme: pw.ThemeData.withFont(
            base: font,
            bold: boldFont,
            italic: font,
            boldItalic: boldFont,
          ),
          margin: pw.EdgeInsets.all(
            preferences.margin.clamp(10, 30) * PdfPageFormat.mm,
          ),
          buildForeground: watermark.export && watermark.visible
              ? (_) => pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Opacity(
                    opacity: watermark.opacity.clamp(0, .5),
                    child: pw.Stack(
                      children: [
                        for (var y = 20.0; y < format.height; y += 135)
                          for (var x = 15.0; x < format.width; x += 210)
                            pw.Positioned(
                              left: x,
                              top: y,
                              child: pw.SizedBox(
                                width: 176.25,
                                height: 75,
                                child: pw.Transform.rotate(
                                  angle: 25 * math.pi / 180,
                                  child: pw.FittedBox(
                                    fit: pw.BoxFit.scaleDown,
                                    child: pw.Text(
                                      watermark.copyWith().text,
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: 15.75,
                                        color: PdfColor.fromInt(0xff24766b),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
        maxPages: 500,
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: base.copyWith(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (_) => render(parsed),
      ),
    );
    return document.save();
  }

  List<pw.InlineSpan> _pdfInline(
    List<md.Node> nodes,
    pw.TextStyle style,
    PdfColor accent, {
    Map<md.Node, ({ui.Size size, Uint8List bytes})> formulas = const {},
    Map<md.Node, ExportImage> images = const {},
    Map<ExportImage, pw.MemoryImage> imageProviders = const {},
    double imageWidth = 450,
    double imageHeight = 600,
  }) => nodes.map((node) {
    if (node is! md.Element) {
      return pw.TextSpan(text: node.textContent, style: style);
    }
    if (node.tag == 'br') return const pw.TextSpan(text: '\n');
    if (node.tag == 'img') {
      final image = images[node];
      if (image == null) {
        return pw.TextSpan(
          text: node.attributes['alt'] ?? 'Image',
          style: style,
        );
      }
      final scale = math.min(
        .75,
        math.min(
          imageWidth / image.size.width,
          imageHeight / image.size.height,
        ),
      );
      return pw.WidgetSpan(
        child: pw.Image(
          imageProviders[image]!,
          width: image.size.width * scale,
          height: image.size.height * scale,
          fit: pw.BoxFit.contain,
        ),
      );
    }
    final formula = formulas[node];
    if (formula != null) {
      return pw.WidgetSpan(
        baseline: -2,
        child: pw.Image(
          pw.MemoryImage(formula.bytes),
          width: math.min(
            formula.size.width * (style.fontSize ?? 10) / 18,
            450,
          ),
          height: math.min(
            formula.size.height * (style.fontSize ?? 10) / 18,
            140,
          ),
          fit: pw.BoxFit.contain,
        ),
      );
    }
    if (node.tag == 'input') {
      return pw.TextSpan(
        text: node.attributes.containsKey('checked') ? '[x] ' : '[ ] ',
      );
    }
    final next = style.copyWith(
      fontWeight: node.tag == 'strong' || node.tag == 'th'
          ? pw.FontWeight.bold
          : style.fontWeight,
      fontStyle: node.tag == 'em' ? pw.FontStyle.italic : style.fontStyle,
      color: node.tag == 'a' || node.tag == 'code' ? accent : style.color,
      decoration: node.tag == 'del'
          ? pw.TextDecoration.lineThrough
          : style.decoration,
      fontSize: node.tag == 'sup' || node.tag == 'sub'
          ? (style.fontSize ?? 10) * .75
          : style.fontSize,
      background: node.tag == 'mark'
          ? pw.BoxDecoration(color: PdfColor.fromInt(0xffffe49b))
          : style.background,
    );
    return pw.TextSpan(
      style: next,
      baseline: node.tag == 'sup'
          ? 3
          : node.tag == 'sub'
          ? -2
          : 0,
      children: _pdfInline(
        node.children ?? [md.Text(node.attributes['alt'] ?? node.textContent)],
        next,
        accent,
        formulas: formulas,
        images: images,
        imageProviders: imageProviders,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      ),
    );
  }).toList();

  Future<Uint8List> docx({
    required String source,
    required String title,
    String? documentPath,
    MarkdownPreferences markdown = const MarkdownPreferences(),
  }) async {
    final archive = Archive();
    final parsed = _parse(source, markdown);
    final images = await ExportImages(documentPath: documentPath)
        .collect(parsed);
    final formulas = await _formulaImages(
      parsed,
      markdown,
      const Color(0xff222222),
    );
    final formulaIds = <md.Node, int>{};
    final diagrams = <md.Node, (int, double, double)>{};
    final imageRelationships = StringBuffer();
    final imageIds = <ExportImage, int>{};
    for (final image in images.values) {
      if (imageIds.containsKey(image)) continue;
      final index = imageIds.length + 1;
      imageIds[image] = index;
      archive.addFile(
        ArchiveFile(
          'word/media/image-$index.png',
          image.bytes.length,
          image.bytes,
        ),
      );
      imageRelationships.write(
        '<Relationship Id="rIdImage$index" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image-$index.png"/>',
      );
    }
    var imageOccurrence = 0;
    String imageDrawing(md.Element node, double imageWidth) {
      final image = images[node];
      if (image == null) return '';
      final index = imageIds[image]!, id = 200000 + ++imageOccurrence;
      final scale = math.min(
        9525,
        math.min(imageWidth / image.size.width, 7000000 / image.size.height),
      );
      final cx = (image.size.width * scale).round(),
          cy = (image.size.height * scale).round();
      final alt = _escape(node.attributes['alt'] ?? '');
      return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$id" name="Image $index" descr="$alt"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="$id" name="Image $index" descr="$alt"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rIdImage$index"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
    }

    final diagramColors = ColorScheme.fromSeed(
      seedColor: const Color(0xff24766b),
    );
    Future<void> collect(md.Node node) async {
      if (markdown.mermaid && _mermaid(node)) {
        try {
          final scene = MarkdownMermaidRenderer.scene(
            node.textContent,
            diagramColors,
          );
          final png = await MarkdownMermaidRenderer.png(
            node.textContent,
            diagramColors,
          );
          final index = diagrams.length + 1;
          diagrams[node] = (index, scene.size.width, scene.size.height);
          archive.addFile(
            ArchiveFile('word/media/mermaid-$index.png', png.length, png),
          );
          imageRelationships.write(
            '<Relationship Id="rIdDiagram$index" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/mermaid-$index.png"/>',
          );
        } catch (_) {
          // Invalid diagrams retain their complete source in the document.
        }
      } else if (node is md.Element) {
        for (final child in node.children ?? <md.Node>[]) {
          await collect(child);
        }
      }
    }

    for (final node in parsed) {
      await collect(node);
    }
    for (final entry in formulas.entries) {
      final index = formulaIds.length + 1;
      formulaIds[entry.key] = index;
      archive.addFile(
        ArchiveFile(
          'word/media/formula-$index.png',
          entry.value.bytes.length,
          entry.value.bytes,
        ),
      );
      imageRelationships.write(
        '<Relationship Id="rIdFormula$index" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/formula-$index.png"/>',
      );
    }
    String formulaDrawing(md.Node node) {
      final image = formulas[node]!, index = formulaIds[node]!;
      final scale = math.min(
        5600000 / image.size.width,
        8000000 / image.size.height,
      );
      final factor = math.min(scale, 12700 * 11 / 18);
      final cx = (image.size.width * factor).round(),
          cy = (image.size.height * factor).round();
      return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="${100000 + index}" name="Formula $index"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="${100000 + index}" name="Formula $index"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rIdFormula$index"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
    }

    void add(String path, String content) =>
        archive.addFile(ArchiveFile.string(path, content));
    String run(
      String text, {
      bool bold = false,
      bool italic = false,
      bool code = false,
      bool highlighted = false,
      bool deleted = false,
      String? vertical,
    }) {
      final content = _escape(text)
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll('\n', '</w:t><w:br/><w:t xml:space="preserve">')
          .replaceAll('\t', '</w:t><w:tab/><w:t xml:space="preserve">');
      return '<w:r><w:rPr>${bold ? '<w:b/>' : ''}${italic ? '<w:i/>' : ''}${code ? '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>' : ''}${highlighted ? '<w:highlight w:val="yellow"/>' : ''}${deleted ? '<w:strike/>' : ''}${vertical == null ? '' : '<w:vertAlign w:val="$vertical"/>'}</w:rPr><w:t xml:space="preserve">$content</w:t></w:r>';
    }

    String inline(
      md.Node node, {
      double imageWidth = 5600000,
      bool bold = false,
      bool italic = false,
      bool code = false,
      bool highlighted = false,
      bool deleted = false,
      String? vertical,
    }) {
      if (node is! md.Element) {
        return run(
          node.textContent,
          bold: bold,
          italic: italic,
          code: code,
          highlighted: highlighted,
          deleted: deleted,
          vertical: vertical,
        );
      }
      if (formulas.containsKey(node)) return formulaDrawing(node);
      if (node.tag == 'img') {
        return images.containsKey(node)
            ? imageDrawing(node, imageWidth)
            : run(node.attributes['alt'] ?? 'Image');
      }
      if (node.tag == 'br') return '<w:r><w:br/></w:r>';
      if (node.tag == 'input') {
        return run(node.attributes.containsKey('checked') ? '[x] ' : '[ ] ');
      }
      return (node.children ??
              [md.Text(node.attributes['alt'] ?? node.textContent)])
          .map(
            (child) => inline(
              child,
              imageWidth: imageWidth,
              bold: bold || node.tag == 'strong',
              italic: italic || node.tag == 'em',
              code: code || node.tag == 'code',
              highlighted: highlighted || node.tag == 'mark',
              deleted: deleted || node.tag == 'del',
              vertical: node.tag == 'sub'
                  ? 'subscript'
                  : node.tag == 'sup'
                  ? 'superscript'
                  : vertical,
            ),
          )
          .join();
    }

    final body = StringBuffer();
    void block(md.Node node) {
      final diagram = diagrams[node];
      if (diagram != null) {
        final (index, width, height) = diagram;
        final scale = math.min(5600000 / width, 8000000 / height);
        final cx = (width * scale).round(), cy = (height * scale).round();
        body.write(
          '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="$cx" cy="$cy"/><wp:docPr id="$index" name="Mermaid $index" descr="Mermaid"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="$index" name="Mermaid $index"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rIdDiagram$index"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>',
        );
        return;
      }
      if (node is! md.Element) {
        if (node.textContent.trim().isNotEmpty) {
          body.write('<w:p>${run(node.textContent)}</w:p>');
        }
        return;
      }
      if (node.tag == 'table') {
        body.write(
          '<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/><w:tblBorders>',
        );
        for (final edge in [
          'top',
          'left',
          'bottom',
          'right',
          'insideH',
          'insideV',
        ]) {
          body.write('<w:$edge w:val="single" w:sz="4" w:color="DDE2DE"/>');
        }
        body.write('</w:tblBorders></w:tblPr>');
        void table(md.Node n) {
          if (n is! md.Element) return;
          if (n.tag == 'tr') {
            body.write('<w:tr>');
            for (final cell in n.children ?? <md.Node>[]) {
              body.write(
                '<w:tc><w:p>${inline(cell, imageWidth: 5600000 / n.children!.length - 140000)}</w:p></w:tc>',
              );
            }
            body.write('</w:tr>');
          } else {
            for (final child in n.children ?? <md.Node>[]) {
              table(child);
            }
          }
        }

        table(node);
        body.write('</w:tbl>');
        return;
      }
      if (node.tag == 'blockquote') {
        for (final child in node.children ?? <md.Node>[]) {
          block(child);
        }
        return;
      }
      if (node.tag == 'ul' || node.tag == 'ol') {
        var i = 1;
        for (final child in node.children ?? <md.Node>[]) {
          body.write(
            '<w:p><w:pPr><w:ind w:left="360" w:hanging="200"/></w:pPr>${run(node.tag == 'ul' ? '• ' : '${i++}. ')}${inline(child)}</w:p>',
          );
        }
        return;
      }
      final heading = RegExp(r'^h([1-6])$').firstMatch(node.tag);
      body.write(
        '<w:p><w:pPr>${heading != null ? '<w:pStyle w:val="Heading${heading[1]}"/><w:keepNext/>' : ''}'
        '${node.tag == 'pre' ? '<w:shd w:fill="F3F6F2"/>' : ''}<w:spacing w:after="180" w:line="320" w:lineRule="auto"/></w:pPr>${inline(node)}</w:p>',
      );
    }

    for (final node in parsed) {
      block(node);
    }
    add(
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>',
    );
    add(
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
    );
    add(
      'word/_rels/document.xml.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>$imageRelationships</Relationships>',
    );
    add(
      'word/styles.xml',
      '<?xml version="1.0" encoding="UTF-8"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:eastAsia="Microsoft YaHei"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>${[for (var i = 1; i <= 6; i++) '<w:style w:type="paragraph" w:styleId="Heading$i"><w:name w:val="heading $i"/><w:pPr><w:outlineLvl w:val="${i - 1}"/></w:pPr><w:rPr><w:b/><w:sz w:val="${i == 1
            ? 42
            : i == 2
            ? 32
            : 26}"/></w:rPr></w:style>'].join()}</w:styles>',
    );
    add(
      'word/document.xml',
      '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000"/></w:sectPr></w:body></w:document>',
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<Uint8List> mindMapPng(
    MindMapNode root,
    ColorScheme colors, {
    MindMapLayout? layout,
  }) async {
    layout ??= MindMapLayout.compute(root);
    final longest = math.max(layout.size.width, layout.size.height);
    final scale = math.min(
      2.0,
      math.min(
        14000 / longest,
        math.sqrt(40000000 / (layout.size.width * layout.size.height)),
      ),
    );
    final recorder = ui.PictureRecorder();
    // Keep picture recording and painting on the same recorder.
    final drawing = Canvas(recorder)..scale(scale);
    drawing.drawRect(
      Offset.zero & layout.size,
      Paint()..color = colors.surface,
    );
    final edgePaint = Paint()
      ..color = colors.primary.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (final path in layout.paths) {
      drawing.drawPath(path, edgePaint);
    }
    for (final entry in layout.rects.entries) {
      final node = layout.nodes[entry.key]!,
          rect = entry.value,
          isRoot = node.id == root.id;
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(7));
      drawing.drawRRect(
        shape,
        Paint()..color = isRoot ? colors.primary : colors.surfaceContainerLow,
      );
      drawing.drawRRect(
        shape,
        Paint()
          ..color = colors.outlineVariant
          ..style = PaintingStyle.stroke,
      );
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
        text: TextSpan(
          text: node.title,
          style: TextStyle(
            color: isRoot ? colors.onPrimary : colors.onSurface,
            fontSize: 12,
            height: 1.6,
            fontFamily: 'Segoe UI',
            fontFamilyFallback: const ['Microsoft YaHei', 'Noto Sans CJK SC'],
          ),
        ),
      );
      painter.layout(maxWidth: rect.width - 24);
      painter.paint(
        drawing,
        Offset(rect.left + 12, rect.center.dy - painter.height / 2),
      );
      painter.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (layout.size.width * scale).ceil(),
      (layout.size.height * scale).ceil(),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
    return bytes;
  }
}

final class _MermaidHtmlSyntax extends md.FencedCodeBlockSyntax {
  _MermaidHtmlSyntax(this.colors);
  final ColorScheme colors;
  String _source = '';

  @override
  List<md.Line> parseChildLines(
    md.BlockParser parser, [
    String openingMarker = '',
    int indent = 0,
  ]) {
    final lines = super.parseChildLines(parser, openingMarker, indent);
    _source = lines.map((line) => line.content).join('\n');
    return lines;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final node = super.parse(parser);
    if (!DocumentExportService._mermaid(node)) return node;
    try {
      final svg = MarkdownMermaidRenderer.svg(_source, colors);
      return md.Element.empty('img')
        ..attributes.addAll({
          'src': 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}',
          'alt': 'Mermaid',
          'class': 'vex-diagram',
        });
    } catch (_) {
      return node;
    }
  }
}
