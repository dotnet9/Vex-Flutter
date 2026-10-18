import 'package:path/path.dart' as p;

final class ImagePreferences {
  const ImagePreferences({
    this.copy = true,
    this.relative = true,
    this.folder = 'assets',
  });
  final bool copy, relative;
  final String folder;

  static bool validFolder(String value) {
    final normalized = value.trim().replaceAll('\\', '/');
    return normalized.isNotEmpty &&
        !p.posix.isAbsolute(normalized) &&
        !RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(normalized) &&
        normalized
            .split('/')
            .every(
              (part) =>
                  part.isNotEmpty &&
                  part != '.' &&
                  part != '..' &&
                  !part.endsWith('.') &&
                  !part.endsWith(' '),
            );
  }

  ImagePreferences copyWith({bool? copy, bool? relative, String? folder}) {
    if (folder != null && !validFolder(folder)) {
      throw const FormatException('Use a relative asset folder without ..');
    }
    return ImagePreferences(
      copy: copy ?? this.copy,
      relative: relative ?? this.relative,
      folder: folder?.trim().replaceAll('\\', '/') ?? this.folder,
    );
  }

  Map<String, Object?> toJson() => {
    'copy': copy,
    'relative': relative,
    'folder': folder,
  };

  factory ImagePreferences.fromJson(Object? value) {
    if (value is! Map) return const ImagePreferences();
    final folder = value['folder'];
    return ImagePreferences(
      copy: value['copy'] != false,
      relative: value['relative'] != false,
      folder: folder is String && validFolder(folder) ? folder : 'assets',
    );
  }
}
