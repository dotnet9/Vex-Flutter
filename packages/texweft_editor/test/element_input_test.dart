import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/src/source_controller.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  for (final changeSelection in [false, true]) {
    testWidgets(
      'source async paste rejects changed ${changeSelection ? 'selection' : 'text'}',
      (tester) async {
        final pending = Completer<Object?>();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? pending.future : null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final editor = MarkdownEditorController(text: 'source');
        final input = MarkdownSourceEditingController(editor);
        editor.select(0);
        input.paste();
        await tester.pump();
        if (changeSelection) {
          editor.select(3);
        } else {
          editor.session.replace('updated');
        }
        pending.complete({'text': 'clipboard'});
        await tester.pump();
        expect(editor.text, changeSelection ? 'source' : 'updated');
        input.dispose();
        editor.dispose();
      },
    );
  }

  testWidgets(
    'linked images remain visible and expose image-specific context',
    (tester) async {
      String? url;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownReader(
              data: '[![Image](image.png)](https://example.com)',
              imageBuilder: (_, _, _) => Container(
                key: ValueKey('linked-image'),
                width: 100,
                height: 100,
                color: Colors.green,
              ),
              onMediaContext: (value, image, occurrence, position) {
                expect(image, isTrue);
                url = value;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = find.byKey(const ValueKey('linked-image'));
      expect(image, findsOneWidget);
      await tester.tap(
        image,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(url, 'image.png');
      expect(tester.takeException(), isNull);
    },
  );
}
