import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  test(
    'character count follows text revisions, not selections or saved state',
    () {
      final controller = MarkdownEditorController(
        text: 'A\u{1f9d1}\u200d\u{1f4bb}e\u0301',
      );
      addTearDown(controller.dispose);
      final document = controller.document;
      expect(controller.characterCount, 3);
      controller.select(1);
      controller.session.markSaved();
      expect(controller.document, same(document));
      expect(controller.characterCount, 3);
      controller.session.replace('updated');
      expect(controller.characterCount, 7);
      controller.session.undo();
      expect(controller.characterCount, 3);
      controller.session.redo();
      expect(controller.characterCount, 7);
    },
  );
}
