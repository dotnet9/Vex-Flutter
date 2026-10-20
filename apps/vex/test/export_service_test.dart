import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/services/export_service.dart';
import 'package:vex/ui/core/palette_tokens.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DocumentExportService();
  final colors = paletteSchemes['weft-light']!;
  const source =
      '# 中文标题\n\n这是一段 **粗体** 和 *斜体*。\n\n## 下一节\n\n- 清单\n- [x] 已完成\n\n| 名称 | 数量 |\n| --- | --- |\n| 维刻 | 2 |\n\n```dart\nprint("hello");\n```';
  test(
    'HTML is standalone and carries the chosen appearance with escaped title',
    () async {
      final html = await service.html(
        source: source,
        title: '标题 <&>',
        colors: colors,
        typography: MarkdownTypography.technical,
      );
      expect(html, contains('<strong>粗体</strong>'));
      expect(html, contains('<table>'));
      expect(html, contains('<title>标题 &lt;&amp;&gt;</title>'));
      expect(html, contains('#24766b'));
      expect(html, contains('border-left:3px solid #24766b'));
      expect(html, isNot(contains('#376c9a')));
      expect(html, isNot(contains('<script')));
    },
  );
  test(
    'HTML heading IDs match Unicode document links and duplicate headings',
    () async {
      const linked =
          '# **中文** &amp; `x_y`\n\n'
          '[跳转](#中文--x_y-1)\n\n# **中文** &amp; `x_y`\n';
      final html = await service.html(
        source: linked,
        title: '导航',
        colors: colors,
        typography: MarkdownTypography.simple,
      );
      expect(html, contains('<h1 id="中文--x_y">'));
      expect(html, contains('<h1 id="中文--x_y-1">'));
      expect(html, contains('href="#%E4%B8%AD%E6%96%87--x_y-1"'));
      expect(html, isNot(contains('<script')));
    },
  );
  test(
    'DOCX contains real OOXML structure, heading styles and a table',
    () async {
      final archive = ZipDecoder().decodeBytes(
        await service.docx(source: source, title: '中文标题'),
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
    },
  );
  test('DOCX code retains newlines, tabs and literal XML characters', () async {
    final archive = ZipDecoder().decodeBytes(
      await service.docx(
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
      final output = Platform.environment['VEX_CAPTURE_DIR'];
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
    final output = Platform.environment['VEX_CAPTURE_DIR'];
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
  test('PNG uses the selected layout and visible branches', () async {
    const root = MindMapNode(
      id: 'root',
      title: 'Root',
      children: [
        MindMapNode(
          id: 'a',
          title: 'A',
          children: [MindMapNode(id: 'b', title: 'B')],
        ),
      ],
    );
    for (final mode in MindMapLayoutMode.values) {
      final layout = MindMapLayout.compute(root, mode: mode, collapsed: {'a'});
      final bytes = await service.mindMapPng(root, colors, layout: layout);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, (layout.size.width * 2).ceil());
      expect(frame.image.height, (layout.size.height * 2).ceil());
      frame.image.dispose();
      codec.dispose();
    }
  });
  test(
    'PNG preserves all six node and connector styles in both themes',
    () async {
      const root = MindMapNode(
        id: 'root',
        title: 'Root',
        children: [
          MindMapNode(id: 'a', title: 'A', subtitle: 'H2'),
          MindMapNode(id: 'b', title: 'B'),
        ],
      );
      final layout = MindMapLayout.compute(root);
      for (final scheme in [colors, paletteSchemes['weft-dark']!]) {
        for (final style in MindMapStyle.values) {
          final bytes = await service.mindMapPng(
            root,
            scheme,
            layout: layout,
            style: style,
          );
          final codec = await ui.instantiateImageCodec(bytes);
          final image = (await codec.getNextFrame()).image;
          try {
            final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            void check(ui.Offset at, ui.Color expected, String reason) {
              final offset =
                  ((at.dy * 2).round() * image.width + (at.dx * 2).round()) * 4;
              final channels = [expected.r, expected.g, expected.b];
              for (var c = 0; c < 3; c++) {
                expect(
                  rgba.getUint8(offset + c),
                  closeTo(channels[c] * 255, 3),
                  reason: '$style $reason',
                );
              }
            }

            for (final entry in layout.rects.entries) {
              final tokens = MindMapNodeStyle.resolve(
                style,
                scheme,
                root: entry.key == root.id,
                branch: layout.branchIndices[entry.key] ?? 0,
              );
              check(
                entry.value.topLeft + const ui.Offset(14, 14),
                ui.Color.alphaBlend(tokens.fill, scheme.surface),
                entry.key,
              );
            }
            for (var i = 0; i < layout.edges.length; i++) {
              final edge = MindMapEdgeStyle.resolve(
                style,
                scheme,
                branch: layout.branchIndices[layout.edges[i].to] ?? 0,
              );
              final metric = layout.paths[i].computeMetrics().first;
              // The middle of the curve is away from node borders and text.
              final point = metric
                  .getTangentForOffset(metric.length / 2)!
                  .position;
              if (style == MindMapStyle.colorful) {
                check(
                  point,
                  ui.Color.alphaBlend(edge.color, scheme.surface),
                  'connector $i',
                );
              }
            }
            final output = Platform.environment['VEX_CAPTURE_DIR'];
            if (output != null) {
              await File(
                '$output/map-${scheme.brightness.name}-${style.name}.png',
              ).writeAsBytes(bytes);
            }
          } finally {
            image.dispose();
            codec.dispose();
          }
        }
      }
    },
  );
}
