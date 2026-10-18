import 'package:flutter_test/flutter_test.dart';

import 'support/render_stability_checks.dart';

void main() {
  testWidgets(
    'scrolling and chapter jumps have stable native document frames',
    (tester) => checkDocumentFrameStability(tester),
  );
}
