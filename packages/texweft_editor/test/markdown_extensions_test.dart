import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:texweft_editor/texweft_editor.dart';

const formulas = [
  r'A = \pi r^2',
  r'E = mc^2',
  r'ax^2 + bx + c = 0',
  r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}',
  r'\int_{-\infty}^{+\infty} e^{-x^2}\,dx = \sqrt{\pi}',
  r'\mathbf{A} = \begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}',
  r'\ce{2H2 + O2 -> 2H2O}',
  r'\ce{N2 + 3H2 <=> 2NH3}',
  r'\ce{H2O}',
  r'\ce{SO4^{2-}}',
];

List<md.Node> parse(
  String source, [
  MarkdownPreferences preferences = const MarkdownPreferences(),
]) => md.Document(
  extensionSet: MarkdownSyntax.extensions(preferences),
  blockSyntaxes: MarkdownSyntax.blocks(preferences),
  inlineSyntaxes: MarkdownSyntax.inlines(preferences),
  encodeHtml: false,
).parseLines(source.split('\n'));

List<md.Element> elements(List<md.Node> nodes) => [
  for (final n in nodes)
    if (n is md.Element) ...[n, ...elements(n.children ?? [])],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all prototype math and mhchem examples have native glyphs and finite layout', () {
    for (final source in formulas) {
      final layout = MarkdownMathRenderer.layout(source, display: true);
      expect(layout.width, greaterThan(0), reason: source);
      expect(layout.height + layout.depth, greaterThan(0), reason: source);
      expect(layout.items, isNotEmpty, reason: source);
    }
    expect(
      () => MarkdownMathRenderer.layout(r'\unknowncommand{x}'),
      throwsFormatException,
    );
    expect(
      () => MarkdownMathRenderer.layout('x' * 8193),
      throwsFormatException,
    );
  });

  test('all seven preferences default on and round-trip independently', () {
    const defaults = MarkdownPreferences();
    expect(defaults.toJson().values, everyElement(isTrue));
    final disabled = defaults.copyWith(
      math: false,
      chemistry: false,
      mermaid: false,
      subscript: false,
      highlight: false,
      autoLink: false,
      softBreak: false,
    );
    expect(
      MarkdownPreferences.fromJson(disabled.toJson()).toJson(),
      disabled.toJson(),
    );
    expect(MarkdownPreferences.fromJson(null).toJson(), defaults.toJson());
  });

  test('math delimiters skip prices, escapes and code; chemistry has independent switch', () {
    const source =
        r'Price $5 and $10, $x^2$ and \(a+b\), `\(code\)` and \$literal. $\ce{H2O}$';
    final math = elements(parse(source)).where((n) => n.tag == 'vex-math');
    expect(math.map((n) => n.attributes['data-tex']), [
      r'x^2',
      'a+b',
      r'\ce{H2O}',
    ]);
    expect(
      elements(parse(source, const MarkdownPreferences(math: false)))
          .where((n) => n.tag == 'vex-math')
          .map((n) => n.attributes['data-tex']),
      [r'\ce{H2O}'],
    );
    expect(
      elements(parse(source, const MarkdownPreferences(chemistry: false)))
          .where((n) => n.tag == 'vex-math'),
      hasLength(2),
    );
    expect(
      elements(parse('```tex\n\$x\$\n```'))
          .where((n) => n.tag.startsWith('vex-math')),
      isEmpty,
    );
  });

  test(
    'display math spans blank lines without swallowing following headings',
    () {
      const source = '\$\$\nx = 1\n\ny = 2\n\$\$\n\n# Next\n\n\\[a+b\\]';
      final nodes = elements(parse(source));
      expect(nodes.where((n) => n.tag == 'vex-math-block'), hasLength(2));
      expect(nodes.where((n) => n.tag == 'h1').single.textContent, 'Next');
      expect(
        elements(parse('\$\$\nmissing end\n\n# Next'))
            .where((n) => n.tag == 'vex-math-block'),
        isEmpty,
      );
    },
  );

  test('inline extensions honor switches without changing explicit links or strikethrough', () {
    const source =
        '==important== H~2~O x^2^ ~~removed~~ https://example.com [link](https://example.org)\nnext';
    final enabled = elements(parse(source)).map((n) => n.tag).toList();
    for (final tag in ['mark', 'sub', 'sup', 'del', 'a', 'br']) {
      expect(enabled, contains(tag));
    }
    final disabled = elements(
      parse(
        source,
        const MarkdownPreferences(
          highlight: false,
          subscript: false,
          autoLink: false,
          softBreak: false,
        ),
      ),
    ).map((n) => n.tag).toList();
    for (final tag in ['mark', 'sub', 'sup', 'br']) {
      expect(disabled, isNot(contains(tag)));
    }
    expect(disabled.where((s) => s == 'a'), hasLength(1));
    expect(disabled, contains('del'));
  });

  testWidgets(
    'phone math, highlights and sub/sup render without overflow in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: MarkdownReader(
                    data:
                        '==重点== H~2~O x^2^ ${formulas.map((s) => '\$$s\$').join('，')}',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(MarkdownMathFormula),
          findsNWidgets(formulas.length),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'display formula source editing preserves CRLF, IME and shared undo',
    (tester) async {
      const original = '\$\$\r\nx = 1\r\n\r\ny = 2\r\n\$\$\r\n\r\n# After';
      final controller = MarkdownEditorController(text: original);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MarkdownMathFormula));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('instant-active-input'));
      expect(field, findsOneWidget);
      expect(find.byType(MarkdownMathFormula), findsOneWidget);
      final input = tester.widget<TextField>(field).controller!;
      const composing = '\$\$\nx = 选\n\$\$';
      input.value = const TextEditingValue(
        text: composing,
        selection: TextSelection.collapsed(offset: 8),
        composing: TextRange(start: 7, end: 8),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.text, original);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(field, findsOneWidget);
      input.value = input.value.copyWith(composing: TextRange.empty);
      await tester.pumpAndSettle();
      expect(controller.text, contains('x = 选'));
      await tester.enterText(field, '\$\$\nx = 3\n\$\$');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.text, '\$\$\r\nx = 3\r\n\$\$\r\n\r\n# After');
      controller.session.undo();
      await tester.pumpAndSettle();
      expect(controller.text, original);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
