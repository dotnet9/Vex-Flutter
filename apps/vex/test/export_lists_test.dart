import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/services/export_service.dart';
import 'package:vex/ui/core/palette_tokens.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DocumentExportService(),
      colors = paletteSchemes['weft-light']!;
  const source = '''# Nested lists

7. Parent with **bold** text

   Second paragraph in the same item.

   - Child one
     3. Grandchild three
     4. Grandchild four
   - [x] Completed task
   - [ ] Pending task

   > Quoted paragraph inside parent.

   ```dart
   print("nested code");
   ```

8. Next parent

   A continued paragraph.

- New top-level list
- Last item

Outside the lists.
''';
  Future<void> capture(String name, List<int> bytes) async {
    final output = Platform.environment['VEX_CAPTURE_DIR'];
    if (output == null) return;
    await Directory(output).create(recursive: true);
    await File('$output/$name').writeAsBytes(bytes);
  }

  test(
    'HTML retains nested lists, ordered starts and separate item paragraphs',
    () async {
      final html = await service.html(
        source: source,
        title: 'Lists',
        colors: colors,
        typography: MarkdownTypography.simple,
      );
      expect(html, contains('<ol start="7">'));
      expect(html, contains('<ol start="3">'));
      expect(html, contains('<p>Second paragraph in the same item.</p>'));
      expect(html, contains('<p>A continued paragraph.</p>'));
      expect(html, contains('<blockquote>'));
      expect(html, contains('language-dart'));
      await capture('export-lists.html', utf8.encode(html));
    },
  );

  test('Word uses native multilevel numbering and unnumbered continuation paragraphs', () async {
    final bytes = await service.docx(source: source, title: 'Lists');
    final archive = ZipDecoder().decodeBytes(bytes);
    String xml(String path) => utf8.decode(archive.findFile(path)!.content);
    final document = xml('word/document.xml'),
        numbering = xml('word/numbering.xml');
    expect(
      xml('[Content_Types].xml'),
      contains('PartName="/word/numbering.xml"'),
    );
    expect(
      xml('word/_rels/document.xml.rels'),
      contains('Target="numbering.xml"'),
    );
    expect(numbering, contains('<w:startOverride w:val="7"/>'));
    expect(numbering, contains('<w:startOverride w:val="3"/>'));
    expect(numbering, contains('w:numFmt w:val="bullet"'));
    expect(document, contains('<w:ilvl w:val="2"/>'));
    expect(document, contains('<w:b/>'));
    expect(document, contains('[x]'));
    expect(document, contains('[ ]'));
    final paragraphs = RegExp(
      r'<w:p>.*?</w:p>',
      dotAll: true,
    ).allMatches(document).map((match) => match[0]!).toList();
    final second = paragraphs.singleWhere(
      (p) => p.contains('Second paragraph'),
    );
    expect(second, contains('<w:ind w:left="360"/>'));
    expect(second, isNot(contains('<w:numPr>')));
    expect(paragraphs.where((p) => p.contains('<w:numPr>')), hasLength(9));
    expect(
      paragraphs.singleWhere((p) => p.contains('Outside the lists.')),
      isNot(contains('<w:numPr>')),
    );
    expect(
      document.indexOf('Grandchild four'),
      lessThan(document.indexOf('Completed task')),
    );
    expect(
      document.indexOf('nested code'),
      lessThan(document.indexOf('Next parent')),
    );
    await capture('export-lists.docx', bytes);
  });

  test('PDF keeps nested item blocks distinct and paginates very long item text', () async {
    final bytes = await service.pdf(
      source: source,
      title: 'Lists',
      colors: colors,
      typography: MarkdownTypography.simple,
    );
    expect(latin1.decode(bytes), startsWith('%PDF-'));
    await capture('export-lists.pdf', bytes);
    final long = await service.pdf(
      source:
          '# Long list item\n\n7. ${List.generate(1600, (i) => 'word$i').join(' ')}\n8. Final item\n',
      title: 'Long list',
      colors: colors,
      typography: MarkdownTypography.simple,
    );
    final count = RegExp(r'/Count\s+(\d+)').firstMatch(latin1.decode(long));
    expect(int.parse(count![1]!), greaterThan(1));
    await capture('export-long-list.pdf', long);
  });
}
