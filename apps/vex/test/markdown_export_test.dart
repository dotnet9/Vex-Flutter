import 'dart:convert';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/export_service.dart';
import 'package:vex/ui/core/palette_tokens.dart';
import 'package:vex/ui/workspace/preferences_dialog.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DocumentExportService(),
      colors = paletteSchemes['weft-light']!;
  const source = r'''# Formula $E=mc^2$

Area $A=\pi r^2$. Water $\ce{H2O}$.

$$
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
$$

$$
\int_{-\infty}^{+\infty} e^{-x^2}\,dx = \sqrt{\pi}
$$

$$
\mathbf{A}=\begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}
$$

$$
\ce{N2 + 3H2 <=> 2NH3}
$$

| Ion | Formula |
| --- | --- |
| Sulfate | $\ce{SO4^{2-}}$ |

==Important== H~2~O x^2^ https://example.com
New line

```mermaid
flowchart LR
A --> B
```
''';

  test('HTML formulas are self-contained nonblank PNGs and syntax settings affect output', () async {
    final html = await service.html(
      source: source,
      title: 'Formulas',
      colors: colors,
      typography: MarkdownTypography.simple,
    );
    final images = RegExp(r'data:image/png;base64,([^" ]+)')
        .allMatches(html)
        .toList();
    expect(images, hasLength(8));
    for (final image in images) {
      final codec = await ui.instantiateImageCodec(base64Decode(image[1]!));
      final frame = await codec.getNextFrame();
      final rgba = (await frame.image.toByteData())!.buffer.asUint8List();
      expect(rgba.where((v) => v != 0).length, greaterThan(20));
      frame.image.dispose();
      codec.dispose();
    }
    expect(html, contains('<mark>Important</mark>'));
    expect(html, contains('<sub>2</sub>'));
    expect(html, contains('<sup>2</sup>'));
    expect(html, contains('data:image/svg+xml;base64,'));
    expect(html, contains('<br />'));
    final plain = await service.html(
      source: source,
      title: 'Off',
      colors: colors,
      typography: MarkdownTypography.simple,
      markdown: const MarkdownPreferences(
        math: false,
        chemistry: false,
        mermaid: false,
        subscript: false,
        highlight: false,
        autoLink: false,
        softBreak: false,
      ),
    );
    expect(plain, isNot(contains('data:image/')));
    expect(plain, contains('==Important== H~2~O x^2^'));
    expect(plain, isNot(contains('href="https://example.com"')));
    expect(plain, contains('https://example.com New line'));
    expect(plain, contains('language-mermaid'));
  });

  test('invalid or untrusted formulas retain escaped source in HTML', () async {
    final html = await service.html(
      source: r'$\unknowncommand{<script>&}$',
      title: 'Error',
      colors: colors,
      typography: MarkdownTypography.simple,
    );
    expect(html, contains('&lt;script&gt;&amp;'));
    expect(html, isNot(contains('<script>')));
    expect(html, isNot(contains('data-tex=')));
  });

  test('PDF embeds actual formula images in headings, paragraphs, blocks and table cells', () async {
    final bytes = await service.pdf(
      source: source,
      title: 'Formulas',
      colors: colors,
      typography: MarkdownTypography.simple,
    );
    final pdf = latin1.decode(bytes);
    expect(pdf, startsWith('%PDF-'));
    expect(
      RegExp(r'/Subtype\s*/Image').allMatches(pdf).length,
      greaterThanOrEqualTo(8),
    );
    final plain = await service.pdf(
      source: source,
      title: 'Off',
      colors: colors,
      typography: MarkdownTypography.simple,
      markdown: const MarkdownPreferences(
        math: false,
        chemistry: false,
        mermaid: false,
      ),
    );
    expect(latin1.decode(plain), isNot(contains('/Subtype /Image')));
  });

  test('Word embeds all formulas and preserves highlight, subscript and superscript', () async {
    final bytes = await service.docx(source: source, title: 'Formulas');
    final archive = ZipDecoder().decodeBytes(bytes);
    final xml = utf8.decode(archive.findFile('word/document.xml')!.content);
    final relations = utf8.decode(
      archive.findFile('word/_rels/document.xml.rels')!.content,
    );
    for (var i = 1; i <= 8; i++) {
      expect(archive.findFile('word/media/formula-$i.png'), isNotNull);
      expect(xml, contains('r:embed="rIdFormula$i"'));
      expect(relations, contains('Target="media/formula-$i.png"'));
    }
    expect(xml, contains('<w:highlight w:val="yellow"/>'));
    expect(xml, contains('w:vertAlign w:val="subscript"'));
    expect(xml, contains('w:vertAlign w:val="superscript"'));
  });

  test('Markdown settings persist without changing document/history', () async {
    final vm = fakeWorkspace();
    vm.editor.session.replace(source);
    final revision = vm.editor.session.revision;
    vm.updateMarkdownPreferences(
      const MarkdownPreferences(math: false, autoLink: false),
    );
    await Future<void>.delayed(Duration.zero);
    final restored = WorkspaceViewModel(
      files: vm.files,
      settings: vm.settings,
      recovery: vm.recovery,
    );
    await restored.initialize(watchFiles: false);
    expect(
      restored.markdownPreferences.toJson(),
      vm.markdownPreferences.toJson(),
    );
    expect(vm.editor.session.revision, revision);
    expect(vm.editor.text, source);
    vm.dispose();
    restored.dispose();
  });

  testWidgets(
    'Markdown page exposes all seven real switches and updates previews',
    (tester) async {
      final vm = fakeWorkspace();
      vm.editor.session.replace(r'$x^2$');
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownMathFormula), findsOneWidget);
      showPreferences(
        tester.element(find.byType(Scaffold).first),
        vm,
        category: PreferenceCategory.markdown,
      );
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(7));
      await tester.tap(find.text(vm.strings.prefMath));
      await tester.pumpAndSettle();
      expect(vm.markdownPreferences.math, isFalse);
      expect(find.byType(MarkdownMathFormula), findsNothing);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
