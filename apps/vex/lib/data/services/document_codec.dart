import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

import '../../domain/file_preferences.dart';

final class DecodedDocument {
  const DecodedDocument(this.text, this.format);
  final String text;
  final TextFileFormat format;
}

String normalizeNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

Future<DecodedDocument> decodeDocument(Uint8List bytes) async {
  var encoding = DocumentEncoding.utf8;
  String text;
  final bom =
      bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf;
  try {
    text = utf8.decode(bom ? bytes.sublist(3) : bytes);
    if (bom) encoding = DocumentEncoding.utf8Bom;
  } on FormatException {
    // Do not silently replace undecodable bytes and later save corrupted text.
    if (bom) rethrow;
    text = await CharsetConverter.decode('GB18030', bytes);
    final roundTrip = await CharsetConverter.encode('GB18030', text);
    if (!_sameBytes(bytes, roundTrip)) {
      throw const FormatException('The file is not valid UTF-8 or GB18030.');
    }
    encoding = DocumentEncoding.gb18030;
  }
  return DecodedDocument(
    normalizeNewlines(text),
    TextFileFormat(
      encoding: encoding,
      newline: text.contains('\r\n')
          ? DocumentNewline.crlf
          : DocumentNewline.lf,
    ),
  );
}

Future<Uint8List> encodeDocument(String text, TextFileFormat format) async {
  final crlf =
      format.newline == DocumentNewline.crlf ||
      (format.newline == DocumentNewline.system && Platform.isWindows);
  final normalized = normalizeNewlines(text);
  final output = crlf ? normalized.replaceAll('\n', '\r\n') : normalized;
  if (format.encoding == DocumentEncoding.gb18030) {
    final bytes = await CharsetConverter.encode('GB18030', output);
    if (await CharsetConverter.decode('GB18030', bytes) != output) {
      throw const FormatException(
        'Some characters cannot be encoded as GB18030.',
      );
    }
    return bytes;
  }
  return Uint8List.fromList([
    if (format.encoding == DocumentEncoding.utf8Bom) ...[0xef, 0xbb, 0xbf],
    ...utf8.encode(output),
  ]);
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
