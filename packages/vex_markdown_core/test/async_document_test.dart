import 'dart:async';

import 'package:test/test.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

void main() {
  for (final large in [false, true]) {
    test('async parse preserves ranges and clean session: large=$large', () async {
      final source =
          '# Root\r\n\r\n${'Body\r\n\r\n' * (large ? 40000 : 1)}## Target\r\nUnicode \u{1f9d1}\u200d\u{1f4bb}\r\n';
      var yielded = false;
      Timer.run(() => yielded = true);
      final parsed = await MarkdownDocument.parseAsync(source);
      if (large) expect(yielded, isTrue);
      expect(parsed.source, source);
      expect(parsed.headings.last.header.slice(source), '## Target\r\n');
      expect(parsed.headings.last.section.end, source.length);
      final session = MarkdownSession.fromDocument(parsed);
      expect(session.document, same(parsed));
      expect(session.isDirty, isFalse);
      expect(session.canUndo, isFalse);
      session.renameHeading(parsed.headings.last.id, 'Renamed');
      session.undo();
      expect(session.text, source);
      expect(session.isDirty, isFalse);
      expect(() => parsed.headings.clear(), throwsUnsupportedError);
    });
  }
}
