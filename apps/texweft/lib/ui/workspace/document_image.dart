import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Resolve relative media from the Markdown file, independently of process cwd.
class DocumentImage extends StatelessWidget {
  const DocumentImage({
    super.key,
    required this.uri,
    this.documentPath,
    this.alt,
  });
  final Uri uri;
  final String? documentPath, alt;

  @override
  Widget build(BuildContext context) {
    final resolved = documentPath == null || uri.hasScheme
        ? uri
        : Uri.file(documentPath!).resolveUri(uri);
    Widget fallback() => Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, size: 22),
          if (alt?.isNotEmpty ?? false) ...[
            const SizedBox(width: 8),
            Flexible(child: Text(alt!)),
          ],
        ],
      ),
    );
    Widget error(BuildContext context, Object error, StackTrace? stack) =>
        fallback();
    final svg =
        resolved.path.toLowerCase().endsWith('.svg') ||
        (resolved.scheme == 'data' &&
            resolved.data?.mimeType == 'image/svg+xml');
    final Widget image;
    if (resolved.scheme == 'http' || resolved.scheme == 'https') {
      image = svg
          ? SvgPicture.network(
              resolved.toString(),
              semanticsLabel: alt,
              errorBuilder: error,
            )
          : Image.network(
              resolved.toString(),
              semanticLabel: alt,
              errorBuilder: error,
            );
    } else if (resolved.scheme == 'data') {
      final bytes = resolved.data!.contentAsBytes();
      image = svg
          ? SvgPicture.memory(bytes, semanticsLabel: alt, errorBuilder: error)
          : Image.memory(bytes, semanticLabel: alt, errorBuilder: error);
    } else if (resolved.scheme == 'file' || resolved.scheme.isEmpty) {
      final file = File.fromUri(resolved);
      image = svg
          ? SvgPicture.file(file, semanticsLabel: alt, errorBuilder: error)
          : Image.file(file, semanticLabel: alt, errorBuilder: error);
    } else if (resolved.scheme == 'resource') {
      image = svg
          ? SvgPicture.asset(
              resolved.path,
              semanticsLabel: alt,
              errorBuilder: error,
            )
          : Image.asset(resolved.path, semanticLabel: alt, errorBuilder: error);
    } else {
      image = fallback();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: image,
    );
  }
}
