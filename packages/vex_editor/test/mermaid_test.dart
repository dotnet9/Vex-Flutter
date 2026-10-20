import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mermaid_core/mermaid_core.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  test('diagram scenes reuse a palette and release older documents', () {
    final colors = ColorScheme.fromSeed(seedColor: Colors.teal);
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );
    const source = 'flowchart LR\n A --> B';
    final original = MarkdownMermaidRenderer.scene(source, colors);
    expect(MarkdownMermaidRenderer.scene(source, colors), same(original));
    expect(MarkdownMermaidRenderer.scene(source, dark), isNot(same(original)));
    expect(MarkdownMermaidRenderer.scene(source, colors), same(original));
    for (var i = 0; i < 24; i++) {
      MarkdownMermaidRenderer.scene('flowchart LR\n A --> B$i', colors);
    }
    expect(
      MarkdownMermaidRenderer.scene(source, colors),
      isNot(same(original)),
    );
  });

  for (final template in MermaidTemplate.values) {
    test('renders approved ${template.name} example', () {
      final scene = const Mermaid(measurer: ApproximateTextMeasurer())
          .render(template.source);
      expect(scene.size.width, greaterThan(0));
      expect(scene.size.height, greaterThan(0));
      final svg = renderSceneToSvg(scene);
      expect(svg, contains('<svg'));
      expect(svg, isNot(contains('NaN')));
      expect(svg, isNot(contains('Infinity')));
    });
  }
}
