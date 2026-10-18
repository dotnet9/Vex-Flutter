import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:markdown/markdown.dart' as md;

/// One export owns its cache; no image bytes survive document changes.
final class ExportImage {
  const ExportImage(this.bytes, this.size);
  final Uint8List bytes;
  final ui.Size size;
}

final class ExportImages {
  ExportImages({this.documentPath});

  static const maxBytes = 32 * 1024 * 1024;
  static const _maxTotalBytes = 96 * 1024 * 1024;
  static const _timeout = Duration(seconds: 12);
  final String? documentPath;
  final _cache = <Uri, ExportImage?>{};
  int _bytes = 0;

  Future<Map<md.Node, ExportImage>> collect(List<md.Node> nodes) async {
    final result = <md.Node, ExportImage>{};
    Future<void> visit(md.Node node) async {
      if (node is! md.Element) return;
      if (node.tag == 'img' && node.attributes['class'] != 'vex-diagram') {
        final image = await load(node.attributes['src'] ?? '');
        if (image != null) result[node] = image;
      } else {
        for (final child in node.children ?? <md.Node>[]) {
          await visit(child);
        }
      }
    }

    for (final node in nodes) {
      await visit(node);
    }
    return result;
  }

  Future<ExportImage?> load(String source) async {
    try {
      var uri = Uri.parse(source);
      if (!uri.hasScheme) {
        // An unsaved document must not read relative to the process cwd.
        if (documentPath == null ||
            documentPath!.startsWith('vex-document:') ||
            uri.hasAuthority ||
            source.isEmpty) {
          return null;
        }
        uri = Uri.file(documentPath!).resolveUri(uri);
      }
      uri = uri.removeFragment();
      if (_cache.containsKey(uri)) return _cache[uri];
      _cache[uri] = null;
      if (_bytes >= _maxTotalBytes) return null;
      final bytes = await _read(uri).timeout(_timeout);
      final image = await _decode(bytes, uri);
      _bytes += image.bytes.length;
      if (_bytes > _maxTotalBytes) return null;
      return _cache[uri] = image;
    } catch (_) {
      // Missing assets and malformed image decoders can also throw FlutterError.
      return null;
    }
  }

  Future<Uint8List> _bounded(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);
    await for (final part in stream) {
      _bytes += part.length;
      if (bytes.length + part.length > maxBytes || _bytes > _maxTotalBytes) {
        throw const FormatException('Image exceeds export size limits');
      }
      bytes.add(part);
    }
    return bytes.takeBytes();
  }

  Future<Uint8List> _read(Uri uri) async {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final client = HttpClient()..connectionTimeout = _timeout;
      // Close the socket even if a peer keeps sending small chunks forever.
      final timer = Timer(_timeout, () => client.close(force: true));
      try {
        var next = uri;
        for (var redirects = 0; redirects <= 5; redirects++) {
          final request = await client.getUrl(next);
          request.followRedirects = false;
          final response = await request.close();
          if (response.isRedirect) {
            final location = response.headers.value(HttpHeaders.locationHeader);
            if (location == null) break;
            next = next.resolve(location);
            if (next.scheme != 'http' && next.scheme != 'https') break;
            // Do not download a redirect body before following the location.
            continue;
          }
          if (response.statusCode != HttpStatus.ok ||
              response.contentLength > maxBytes) {
            break;
          }
          return await _bounded(response);
        }
        throw const FormatException('Image download failed');
      } finally {
        timer.cancel();
        client.close(force: true);
      }
    }
    if (uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (await file.length() > maxBytes) {
        throw const FormatException('Image exceeds export size limits');
      }
      return _bounded(file.openRead());
    }
    final Uint8List bytes;
    if (uri.scheme == 'data') {
      if (uri.toString().length > maxBytes * 4) {
        throw const FormatException('Image exceeds export size limits');
      }
      bytes = uri.data!.contentAsBytes();
    } else if (uri.scheme == 'resource') {
      bytes = (await rootBundle.load(uri.path)).buffer.asUint8List();
    } else {
      throw const FormatException('Unsupported image URI');
    }
    _bytes += bytes.length;
    if (bytes.length > maxBytes || _bytes > _maxTotalBytes) {
      throw const FormatException('Image exceeds export size limits');
    }
    return bytes;
  }

  Future<ExportImage> _decode(Uint8List bytes, Uri uri) async {
    final svg =
        uri.path.toLowerCase().endsWith('.svg') ||
        uri.data?.mimeType == 'image/svg+xml' ||
        String.fromCharCodes(bytes.take(256)).contains('<svg');
    if (svg) {
      final info = await vg.loadPicture(SvgBytesLoader(bytes), null);
      try {
        final size = info.size;
        final scale = _scale(size);
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder)
          ..scale(scale)
          ..drawPicture(info.picture);
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(
            math.max(1, (size.width * scale).round()),
            math.max(1, (size.height * scale).round()),
          );
          return await _png(image, size);
        } finally {
          picture.dispose();
        }
      } finally {
        info.picture.dispose();
      }
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final size = ui.Size(
          descriptor.width.toDouble(),
          descriptor.height.toDouble(),
        );
        final scale = _scale(size);
        final codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (size.width * scale).round()),
          targetHeight: math.max(1, (size.height * scale).round()),
        );
        try {
          // Static exports use the first frame of animated GIF/WebP images.
          final frame = await codec.getNextFrame();
          return await _png(frame.image, size);
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  double _scale(ui.Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        size.width * size.height > 40000000) {
      throw const FormatException('Image dimensions exceed export limits');
    }
    return math.min(
      1,
      math.min(
        4096 / math.max(size.width, size.height),
        math.sqrt(16000000 / (size.width * size.height)),
      ),
    );
  }

  Future<ExportImage> _png(ui.Image image, ui.Size size) async {
    try {
      return ExportImage(
        (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
        size,
      );
    } finally {
      image.dispose();
    }
  }
}
