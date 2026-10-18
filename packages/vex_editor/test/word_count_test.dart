import 'package:flutter_test/flutter_test.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  test('word count follows text revisions, not selections or saved state', () {
    final controller = MarkdownEditorController(
      text: 'Hello world \u4e2d\u6587 \u{1f9d1}\u200d\u{1f4bb}',
    );
    addTearDown(controller.dispose);
    final document = controller.document;
    expect(controller.wordCount, 4);
    controller.select(1);
    controller.session.markSaved();
    expect(controller.document, same(document));
    expect(controller.wordCount, 4);
    controller.session.replace('updated');
    expect(controller.wordCount, 1);
    controller.session.undo();
    expect(controller.wordCount, 4);
    controller.session.redo();
    expect(controller.wordCount, 1);
  });
}
