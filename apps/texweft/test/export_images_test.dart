import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/data/services/export_images.dart';
import 'package:texweft/data/services/export_service.dart';
import 'package:texweft/ui/core/palette_tokens.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = DocumentExportService(),
      colors = paletteSchemes['weft-light']!;
  late Directory directory;
  late Uint8List png;
  late String documentPath, source;

  Future<Uint8List> bitmap(int width, int height) async {
    final recorder = ui.PictureRecorder(), paint = ui.Paint();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint..color = const ui.Color(0xff24766b),
    );
    canvas.drawRect(
      ui.Rect.fromLTWH(width * .5, 0, width * .5, height.toDouble()),
      paint..color = const ui.Color(0xffd85367),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final result = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
    return result;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vex-export-images-');
    documentPath = '${directory.path}/document.md';
    png = await bitmap(320, 180);
    await File('${directory.path}/图 & 像.png').writeAsBytes(png);
    source =
        '# Images\n\n![图 & 像](<图%20&%20像.png>)\n\n'
        '重复 ![same](<图%20&%20像.png>)\n\n'
        '| Image | Description |\n| --- | --- |\n'
        '| ![cell](<图%20&%20像.png>) | Caption |\n\n'
        '- ![list](<图%20&%20像.png>)\n\n'
        '![missing](missing.png)';
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'relative, data, file, asset and SVG sources resolve independently of cwd',
    () async {
      final images = ExportImages(documentPath: documentPath);
      final relative = await images.load('图%20&%20像.png');
      expect(relative, isNotNull);
      expect(relative!.size, const ui.Size(320, 180));
      expect(await images.load('图%20&%20像.png'), same(relative));
      expect(
        await images.load(Uri.file('${directory.path}/图 & 像.png').toString()),
        same(relative),
      );
      expect(
        await images.load(
          Uri.dataFromBytes(png, mimeType: 'image/png').toString(),
        ),
        isNotNull,
      );
      final svg = await images.load('resource:assets/brand/logo.svg');
      expect(svg, isNotNull);
      expect(svg!.bytes.take(4), [137, 80, 78, 71]);
      expect(await ExportImages().load('assets/brand/logo.png'), isNull);
      expect(await images.load('javascript:alert(1)'), isNull);
      expect(await images.load('resource:missing.png'), isNull);
      expect(await images.load('data:image/png;base64,not-an-image'), isNull);
    },
  );

  test(
    'local file limits and invalid bitmaps fall back without failing export',
    () async {
      final file = await File('${directory.path}/large.png')
          .open(mode: FileMode.write);
      await file.truncate(ExportImages.maxBytes + 1);
      await file.close();
      await File('${directory.path}/invalid.png')
          .writeAsString('not a picture');
      final images = ExportImages(documentPath: documentPath);
      expect(await images.load('large.png'), isNull);
      expect(await images.load('invalid.png'), isNull);
      expect(await images.load('missing.png'), isNull);
      expect(await images.load('图%20&%20像.png'), isNotNull);
    },
  );

  test(
    'HTTP redirects and duplicate images use one bounded download',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      server.listen((request) async {
        requests.add(request.uri.path);
        if (request.uri.path == '/redirect') {
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set(HttpHeaders.locationHeader, '/image');
        } else if (request.uri.path == '/unsafe-redirect') {
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set(
              HttpHeaders.locationHeader,
              Uri.file('${directory.path}/图 & 像.png').toString(),
            );
        } else if (request.uri.path == '/large') {
          request.response.contentLength = ExportImages.maxBytes + 1;
        } else if (request.uri.path == '/image') {
          request.response
            ..headers.contentType = ContentType('image', 'png')
            ..add(png);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        try {
          await request.response.close();
        } on HttpException {
          // The oversized header is enough for the client to reject the image.
        }
      });
      try {
        final uri = 'http://127.0.0.1:${server.port}/redirect';
        final images = ExportImages();
        final image = await images.load(uri);
        expect(image, isNotNull);
        expect(await images.load(uri), same(image));
        expect(requests, ['/redirect', '/image']);
        expect(
          await images.load('http://127.0.0.1:${server.port}/missing'),
          isNull,
        );
        expect(
          await images.load('http://127.0.0.1:${server.port}/unsafe-redirect'),
          isNull,
        );
        expect(
          await images.load('http://127.0.0.1:${server.port}/large'),
          isNull,
        );
      } finally {
        await server.close(force: true);
      }
    }, _NetworkOverrides()),
  );

  test('HTML embeds all available images and leaves escaped alt text for missing media', () async {
    final html = await service.html(
      source: source,
      documentPath: documentPath,
      title: 'Images',
      colors: colors,
      typography: MarkdownTypography.simple,
    );
    expect(RegExp('data:image/png;base64,').allMatches(html), hasLength(4));
    expect(html, contains('width="320" height="180"'));
    expect(html, contains('alt="图 &amp; 像"'));
    expect(html, contains('<span class="vex-missing-image">missing</span>'));
    expect(html, isNot(contains('src="missing.png"')));
    expect(html, isNot(contains(directory.path)));
  });

  test('PDF embeds reusable images in text, lists and tables without aspect distortion', () async {
    final bytes = await service.pdf(
      source: source,
      documentPath: documentPath,
      title: 'Images',
      colors: colors,
      typography: MarkdownTypography.simple,
    );
    final pdf = latin1.decode(bytes);
    expect(pdf, startsWith('%PDF-'));
    // One shared color image and its alpha mask, not four image copies.
    expect(RegExp(r'/Subtype\s*/Image').allMatches(pdf), hasLength(2));
    expect(pdf, contains('/Width 320'));
    expect(pdf, contains('/Height 180'));
    final output = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    if (output != null) {
      await Directory(output).create(recursive: true);
      await File('$output/export-images.pdf').writeAsBytes(bytes);
    }
  });

  test('Word embeds once, uses unique drawing IDs and retains XML-safe descriptions', () async {
    final bytes = await service.docx(
      source: source,
      title: 'Images',
      documentPath: documentPath,
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final xml = utf8.decode(archive.findFile('word/document.xml')!.content);
    final relations = utf8.decode(
      archive.findFile('word/_rels/document.xml.rels')!.content,
    );
    expect(
      archive.files.where((file) => file.name.startsWith('word/media/image-')),
      hasLength(1),
    );
    expect(RegExp('r:embed="rIdImage1"').allMatches(xml), hasLength(4));
    expect(
      RegExp(r'<wp:docPr id="(\d+)"').allMatches(xml).map((m) => m[1]).toSet(),
      hasLength(4),
    );
    expect(xml, contains('descr="图 &amp; 像"'));
    expect(xml, contains('missing'));
    expect(relations, contains('Target="media/image-1.png"'));
    expect(xml, isNot(contains(directory.path)));
    final output = Platform.environment['TEXWEFT_CAPTURE_DIR'];
    if (output != null) {
      await File('$output/export-images.docx').writeAsBytes(bytes);
    }
  });

  test(
    'portrait and landscape images scale into PDF pages and Word cells',
    () async {
      await File('${directory.path}/tall.png')
          .writeAsBytes(await bitmap(240, 2400));
      await File('${directory.path}/wide.png')
          .writeAsBytes(await bitmap(2400, 240));
      const source =
          '# Large images\n\n![tall](tall.png)\n\n![wide](wide.png)\n\n'
          '| A | B |\n| --- | --- |\n| ![wide](wide.png) | Text |';
      final bytes = await service.pdf(
        source: source,
        documentPath: documentPath,
        title: 'Large images',
        colors: colors,
        typography: MarkdownTypography.simple,
      );
      expect(
        RegExp(r'/Subtype\s*/Image').allMatches(latin1.decode(bytes)),
        isNotEmpty,
      );
      final output = Platform.environment['TEXWEFT_CAPTURE_DIR'];
      if (output != null) {
        await File('$output/export-large-images.pdf').writeAsBytes(bytes);
        await File('$output/export-large-images.docx').writeAsBytes(
          await service.docx(
            source: source,
            documentPath: documentPath,
            title: 'Large images',
          ),
        );
      }
    },
  );
}

class _NetworkOverrides extends HttpOverrides {}
