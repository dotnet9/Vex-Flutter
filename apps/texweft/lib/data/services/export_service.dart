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

/// Native document encoders. No browser engine or HTML-to-PDF WebView.
final class DocumentExportService {
  static List<md.Node> _parse(String source) => md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parseLines(source.split('\n'));
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
  static String _escape(String value) => const HtmlEscape().convert(value);

  static Future<pw.Font> _pdfFont(String name) async {
    final packed = await rootBundle.load('assets/fonts/$name.ttf.z');
    final bytes = const ZLibDecoder().decodeBytes(packed.buffer.asUint8List());
    return pw.Font.ttf(ByteData.sublistView(bytes));
  }

  String html({
    required String source,
    required String title,
    required ColorScheme colors,
    required MarkdownTypography typography,
    bool compact = false,
  }) {
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
    final body = md.markdownToHtml(
      source,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: true,
    );
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
</style></head><body><article>$body</article></body></html>''';
  }

  Future<Uint8List> pdf({
    required String source,
    required String title,
    required ColorScheme colors,
    required MarkdownTypography typography,
    bool compact = false,
  }) async {
    final font = await _pdfFont('NotoSansSC');
    final boldFont = await _pdfFont('NotoSansSC-SemiBold');
    final accent = PdfColor.fromInt(colors.primary.toARGB32()),
        line = PdfColor.fromInt(colors.outlineVariant.toARGB32());
    final document = pw.Document(title: title, author: 'Texweft');
    final base = pw.TextStyle(
      font: font,
      fontSize: 10,
      lineSpacing: compact ? 3 : 5,
      color: PdfColors.grey900,
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
    List<pw.Widget> render(List<md.Node> nodes, {int depth = 0}) {
      final result = <pw.Widget>[];
      for (final node in nodes) {
        if (node is! md.Element) {
          if (node.textContent.trim().isNotEmpty) {
            result.add(paragraph(node.textContent));
          }
          continue;
        }
        final heading = RegExp(r'^h([1-6])$').firstMatch(node.tag);
        if (heading != null) {
          final level = int.parse(heading[1]!);
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
              child: pw.Text(
                node.textContent,
                style: base.copyWith(
                  fontSize: level == 1
                      ? 22
                      : level == 2
                      ? 15
                      : 12,
                  fontWeight: pw.FontWeight.bold,
                  color:
                      level == 2 && typography == MarkdownTypography.technical
                      ? accent
                      : PdfColors.grey900,
                ),
              ),
            ),
          );
        } else if (node.tag == 'pre') {
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
          final rows = <List<String>>[];
          void collect(md.Node n) {
            if (n is md.Element && n.tag == 'tr') {
              rows.add(
                (n.children ?? []).map((cell) => cell.textContent).toList(),
              );
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
                child: pw.TableHelper.fromTextArray(
                  data: rows,
                  headerStyle: base.copyWith(fontWeight: pw.FontWeight.bold),
                  cellStyle: base,
                  border: pw.TableBorder.all(color: line),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                  cellPadding: const pw.EdgeInsets.all(7),
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(44),
        maxPages: 500,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
          italic: font,
          boldItalic: boldFont,
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: base.copyWith(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (_) => render(_parse(source)),
      ),
    );
    return document.save();
  }

  List<pw.InlineSpan> _pdfInline(
    List<md.Node> nodes,
    pw.TextStyle style,
    PdfColor accent,
  ) => nodes.map((node) {
    if (node is! md.Element) {
      return pw.TextSpan(text: node.textContent, style: style);
    }
    if (node.tag == 'br') return const pw.TextSpan(text: '\n');
    if (node.tag == 'input') {
      return pw.TextSpan(
        text: node.attributes.containsKey('checked') ? '[x] ' : '[ ] ',
      );
    }
    final next = style.copyWith(
      fontWeight: node.tag == 'strong' ? pw.FontWeight.bold : style.fontWeight,
      fontStyle: node.tag == 'em' ? pw.FontStyle.italic : style.fontStyle,
      color: node.tag == 'a' || node.tag == 'code' ? accent : style.color,
      decoration: node.tag == 'del'
          ? pw.TextDecoration.lineThrough
          : style.decoration,
    );
    return pw.TextSpan(
      style: next,
      children: _pdfInline(
        node.children ?? [md.Text(node.attributes['alt'] ?? node.textContent)],
        next,
        accent,
      ),
    );
  }).toList();

  Uint8List docx({required String source, required String title}) {
    final archive = Archive();
    void add(String path, String content) =>
        archive.addFile(ArchiveFile.string(path, content));
    String run(
      String text, {
      bool bold = false,
      bool italic = false,
      bool code = false,
    }) {
      final content = _escape(text)
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll('\n', '</w:t><w:br/><w:t xml:space="preserve">')
          .replaceAll('\t', '</w:t><w:tab/><w:t xml:space="preserve">');
      return '<w:r><w:rPr>${bold ? '<w:b/>' : ''}${italic ? '<w:i/>' : ''}${code ? '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>' : ''}</w:rPr><w:t xml:space="preserve">$content</w:t></w:r>';
    }

    String inline(
      md.Node node, {
      bool bold = false,
      bool italic = false,
      bool code = false,
    }) {
      if (node is! md.Element) {
        return run(node.textContent, bold: bold, italic: italic, code: code);
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
              bold: bold || node.tag == 'strong',
              italic: italic || node.tag == 'em',
              code: code || node.tag == 'code',
            ),
          )
          .join();
    }

    final body = StringBuffer();
    void block(md.Node node) {
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
              body.write('<w:tc><w:p>${inline(cell)}</w:p></w:tc>');
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

    for (final node in _parse(source)) {
      block(node);
    }
    add(
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>',
    );
    add(
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
    );
    add(
      'word/_rels/document.xml.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
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
      '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000"/></w:sectPr></w:body></w:document>',
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
