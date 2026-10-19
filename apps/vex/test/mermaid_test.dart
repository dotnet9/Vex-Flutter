import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/export_service.dart';
import 'package:vex/ui/core/palette_tokens.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DocumentExportService(),
      colors = paletteSchemes['weft-light']!;
  final source = MermaidTemplate.values
      .map((t) => '## ${t.zh}${t.markdown}')
      .join();

  test(
    'all 22 HTML diagrams are offline SVG images, not unrendered code',
    () async {
      final html = await service.html(
        source: source,
        title: 'Mermaid',
        colors: colors,
        typography: MarkdownTypography.simple,
      );
      final images = RegExp(r'data:image/svg\+xml;base64,([^" ]+)')
          .allMatches(html)
          .toList();
      expect(images, hasLength(22));
      for (final image in images) {
        final svg = utf8.decode(base64Decode(image[1]!));
        expect(svg, contains('<svg'));
        expect(svg, isNot(contains('NaN')));
        expect(svg, isNot(contains('javascript:')));
      }
      expect(html, isNot(contains('language-mermaid')));
      expect(html, isNot(contains('<script')));
    },
  );

  test(
    'invalid HTML diagram retains escaped source and normal code stays code',
    () async {
      final html = await service.html(
        source: '```mermaid\nunknown <script>alert(1)</script>\n```\n\n```dart\nprint("hello");\n```',
        title: 'Invalid',
        colors: colors,
        typography: MarkdownTypography.simple,
      );
      expect(html, contains('language-mermaid'));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('language-dart'));
      expect(html, isNot(contains('<script>')));
    },
  );

  test(
    'all 22 diagrams export as actual PDF graphics with Chinese fonts',
    () async {
      final bytes = await service.pdf(
        source: source,
        title: 'Mermaid',
        colors: colors,
        typography: MarkdownTypography.simple,
      );
      final structure = latin1.decode(bytes);
      expect(structure, startsWith('%PDF-'));
      expect(structure, contains('/FontFile2'));
      final pages = int.parse(
        RegExp(r'/Count\s+(\d+)').firstMatch(structure)![1]!,
      );
      expect(pages, greaterThanOrEqualTo(6));
      expect(bytes.length, greaterThan(20000));
    },
  );

  test(
    'Word includes raster diagrams with matching image relationships',
    () async {
      final bytes = await service.docx(source: source, title: 'Mermaid');
      final archive = ZipDecoder().decodeBytes(bytes);
      final document = utf8.decode(
        archive.findFile('word/document.xml')!.content,
      );
      final relations = utf8.decode(
        archive.findFile('word/_rels/document.xml.rels')!.content,
      );
      for (var index = 1; index <= 22; index++) {
        final image = archive.findFile('word/media/mermaid-$index.png');
        expect(
          image,
          isNotNull,
          reason: MermaidTemplate.values[index - 1].name,
        );
        expect(image!.content.take(4).toList(), [137, 80, 78, 71]);
        expect(document, contains('r:embed="rIdDiagram$index"'));
        expect(relations, contains('Target="media/mermaid-$index.png"'));
      }
    },
  );

  test('example document never replaces existing unsaved content', () async {
    final vm = fakeWorkspace();
    vm.editor.session.replace('正在写的内容');
    final previous = vm.current;
    vm.openMermaidExamples();
    expect(previous.editor.text, '正在写的内容');
    expect(vm.current, isNot(same(previous)));
    expect(vm.editor.session.isDirty, isTrue);
    expect(
      vm.editor.document.blocks.where((b) => b.kind.name == 'code'),
      hasLength(22),
    );
    await vm.finishPendingSaves();
    vm.dispose();
  });

  testWidgets('phone picker inserts into the initially empty workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = fakeWorkspace();
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip(vm.strings.mermaidDiagrams));
    await tester.tap(find.byTooltip(vm.strings.mermaidDiagrams));
    await tester.pumpAndSettle();
    expect(find.text('过程与行为'), findsNothing);
    expect(
      find.byKey(const ValueKey('mermaid-template-flowchart')),
      findsOneWidget,
    );
    final item = find.byKey(const ValueKey('mermaid-template-sequence'));
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(vm.editor.text, contains('```mermaid\nsequenceDiagram'));
    expect(find.byType(MarkdownMermaidBlock), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
