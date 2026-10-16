import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/data/services/export_service.dart';
import 'package:texweft/ui/core/palette_tokens.dart';
import 'package:texweft_editor/texweft_editor.dart';
import 'package:texweft_mindmap/texweft_mindmap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DocumentExportService();
  final colors = paletteSchemes['weft-light']!;
  const source =
      '# 中文标题\n\n这是一段 **粗体** 和 *斜体*。\n\n## 下一节\n\n- 清单\n- [x] 已完成\n\n| 名称 | 数量 |\n| --- | --- |\n| 笺纬 | 2 |\n\n```dart\nprint("hello");\n```';
  test(
    'HTML is standalone and carries the chosen appearance with escaped title',
    () {
      final html = service.html(
        source: source,
        title: '标题 <&>',
        colors: colors,
        typography: MarkdownTypography.technical,
      );
      expect(html, contains('<strong>粗体</strong>'));
      expect(html, contains('<table>'));
      expect(html, contains('<title>标题 &lt;&amp;&gt;</title>'));
      expect(html, contains('#24766b'));
      expect(html, isNot(contains('<script')));
    },
  );
  test('DOCX contains real OOXML structure, heading styles and a table', () {
    final archive = ZipDecoder().decodeBytes(
      service.docx(source: source, title: '中文标题'),
    );
    final xml = utf8.decode(archive.findFile('word/document.xml')!.content);
    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    expect(xml, contains('w:pStyle w:val="Heading1"'));
    expect(xml, contains('中文标题'));
    expect(xml, contains('<w:tbl>'));
    expect(xml, contains('<w:b/>'));
    expect(xml, contains('[x]'));
    expect(xml, contains('print(&quot;hello&quot;);'));
    expect(xml, isNot(contains('&amp;quot;')));
  });
  test('DOCX code retains newlines, tabs and literal XML characters', () {
    final archive = ZipDecoder().decodeBytes(
      service.docx(
        source: '```text\nfirst <tag> & value\n\tsecond\n```',
        title: 'Code',
      ),
    );
    final xml = utf8.decode(archive.findFile('word/document.xml')!.content);
    expect(xml, contains('first &lt;tag&gt; &amp; value'));
    expect(xml, contains('<w:br/>'));
    expect(xml, contains('<w:tab/>'));
  });
  test(
    'PDF embeds the offline Chinese font and produces a valid document',
    () async {
      final bytes = await service.pdf(
        source: source,
        title: '中文标题',
        colors: colors,
        typography: MarkdownTypography.simple,
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      final structure = latin1.decode(bytes);
      expect(structure, contains('/ToUnicode'));
      expect(structure, contains('/FontFile2'));
      expect(structure.trimRight(), endsWith('%%EOF'));
      final output = Platform.environment['TEXWEFT_CAPTURE_DIR'];
      if (output != null) {
        await Directory(output).create(recursive: true);
        await File('$output/export-chinese.pdf').writeAsBytes(bytes);
      }
    },
  );
  test('long code blocks paginate instead of exceeding one PDF page', () async {
    final bytes = await service.pdf(
      source:
          '```text\n${List.generate(150, (i) => 'line $i: 中文代码').join('\n')}\n```',
      title: 'Long code',
      colors: colors,
      typography: MarkdownTypography.simple,
    );
    final count = RegExp(r'/Count\s+(\d+)').firstMatch(latin1.decode(bytes));
    expect(count, isNotNull);
    expect(int.parse(count![1]!), greaterThan(1));
    final output = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    if (output != null) {
      await File('$output/export-long-code.pdf').writeAsBytes(bytes);
    }
  });
  test('PNG exports all nodes at nonzero dimensions', () async {
    final bytes = await service.mindMapPng(
      const MindMapNode(
        id: 'root',
        title: '中文导图',
        children: [MindMapNode(id: 'a', title: '子章节')],
      ),
      colors,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(500));
    expect(frame.image.height, greaterThan(100));
    frame.image.dispose();
    codec.dispose();
  });
}
