import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/data/services/document_codec.dart';
import 'package:vex/data/services/file_service.dart';
import 'package:vex/domain/file_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native GB18030 handles Chinese and four-byte characters', (
    tester,
  ) async {
    const source = '# 维刻 Vex\n中文与四字节字符 \u{20000}\n';
    const format = TextFileFormat(
      encoding: DocumentEncoding.gb18030,
      newline: DocumentNewline.crlf,
    );
    final bytes = await encodeDocument(source, format);
    expect(bytes, containsAllInOrder([0x95, 0x32, 0x82, 0x36]));
    final decoded = await decodeDocument(bytes);
    expect(decoded.text, source);
    expect(decoded.format.encoding, DocumentEncoding.gb18030);
    expect(decoded.format.newline, DocumentNewline.crlf);
    final dir = await Directory.systemTemp.createTemp('vex-gb18030-');
    try {
      final path = '${dir.path}/note.md';
      await File(path).writeAsBytes(bytes);
      final files = NativeDocumentFileService();
      final opened = await files.read(path);
      await files.write(
        path,
        '$source追加',
        expected: opened.text,
        format: opened.format,
      );
      expect((await files.read(path)).text, '$source追加');
    } finally {
      expect(dir.absolute.path, startsWith(Directory.systemTemp.absolute.path));
      await dir.delete(recursive: true);
    }
  });
}
