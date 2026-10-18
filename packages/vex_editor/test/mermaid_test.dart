import 'package:flutter_test/flutter_test.dart';
import 'package:mermaid_core/mermaid_core.dart';
import 'package:vex_editor/src/mermaid_catalog.dart';

void main() {
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
