import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/image_preferences.dart';

final class PickedImageAsset {
  const PickedImageAsset(this.name, this.bytes, {this.path});
  final String name;
  final Uint8List bytes;
  final String? path;
}

class ImageAssetService {
  static const _types = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.bmp': 'image/bmp',
    '.svg': 'image/svg+xml',
  };

  Future<PickedImageAsset?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _types.keys.map((key) => key.substring(1)).toList(),
    );
    if (file == null) return null;
    return PickedImageAsset(
      file.name,
      await file.readAsBytes(),
      path: Platform.isAndroid || Platform.isIOS ? null : file.path,
    );
  }

  Future<String> markdown(
    PickedImageAsset image, {
    required String? documentPath,
    required ImagePreferences preferences,
  }) async {
    final extension = p.extension(image.name).toLowerCase();
    final mime = _types[extension];
    if (mime == null ||
        image.bytes.isEmpty ||
        image.bytes.length > 32 * 1024 * 1024) {
      throw const FormatException('Unsupported image or image exceeds 32 MB');
    }
    final localDocument = documentPath != null && p.isAbsolute(documentPath);
    final localSource = image.path != null && p.isAbsolute(image.path!);
    String destination;
    if (preferences.copy && localDocument) {
      if (!ImagePreferences.validFolder(preferences.folder)) {
        throw const FormatException('Invalid asset directory');
      }
      final root = await Directory(p.dirname(documentPath))
          .resolveSymbolicLinks();
      var directory = root;
      // Do not follow resource-directory links outside the document tree.
      for (final part in preferences.folder.replaceAll('\\', '/').split('/')) {
        final next = p.join(directory, part);
        final type = await FileSystemEntity.type(next, followLinks: false);
        if (type == FileSystemEntityType.link) {
          throw const FileSystemException(
            'Asset directories cannot be symlinks',
          );
        }
        if (type == FileSystemEntityType.notFound) {
          await Directory(next).create();
        }
        directory = await Directory(next).resolveSymbolicLinks();
        if (!p.isWithin(root, directory)) {
          throw const FileSystemException(
            'Asset directory is outside the document',
          );
        }
      }
      var stem = p
          .basenameWithoutExtension(image.name)
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
          .replaceAll(RegExp(r'[ .]+$'), '');
      if (stem.isEmpty ||
          RegExp(
            r'^(CON|PRN|AUX|NUL|COM\d|LPT\d)$',
            caseSensitive: false,
          ).hasMatch(stem)) {
        stem = 'image';
      }
      stem = String.fromCharCodes(stem.runes.take(90));
      var suffix = 0;
      while (true) {
        final file = File(
          p.join(directory, '$stem${suffix == 0 ? '' : '-$suffix'}$extension'),
        );
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.file &&
            listEquals(await file.readAsBytes(), image.bytes)) {
          destination = file.path;
          break;
        }
        if (type == FileSystemEntityType.notFound) {
          try {
            await file.create(exclusive: true);
          } on FileSystemException {
            if (await FileSystemEntity.type(file.path, followLinks: false) ==
                FileSystemEntityType.notFound) {
              rethrow;
            }
            suffix++;
            continue;
          }
          try {
            await file.writeAsBytes(image.bytes, flush: true);
          } catch (_) {
            await file.delete();
            rethrow;
          }
          destination = file.path;
          break;
        }
        suffix++;
      }
    } else if (!preferences.copy && localSource) {
      destination = image.path!;
    } else {
      final uri = Uri.dataFromBytes(image.bytes, mimeType: mime);
      return _markdown(image.name, uri.toString());
    }
    final relative = preferences.relative && localDocument
        ? p.relative(destination, from: p.dirname(documentPath))
        : destination;
    final uri = p.isAbsolute(relative)
        ? Uri.file(relative)
        : Uri(path: relative.replaceAll('\\', '/'));
    return _markdown(image.name, uri.toString());
  }

  String _markdown(String name, String uri) {
    final alt = p
        .basenameWithoutExtension(name)
        .replaceAll(RegExp(r'[\r\n]'), ' ')
        .replaceAll('\\', '\\\\')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]');
    return '![$alt](<$uri>)';
  }
}
