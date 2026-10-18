enum DocumentEncoding { utf8, utf8Bom, gb18030 }

enum DocumentNewline { system, lf, crlf }

final class TextFileFormat {
  const TextFileFormat({
    this.encoding = DocumentEncoding.utf8,
    this.newline = DocumentNewline.system,
  });
  final DocumentEncoding encoding;
  final DocumentNewline newline;

  Map<String, Object?> toJson() => {
    'encoding': encoding.name,
    'newline': newline.name,
  };

  factory TextFileFormat.fromJson(Map data) => TextFileFormat(
    encoding:
        DocumentEncoding.values
            .where((v) => v.name == data['encoding'])
            .firstOrNull ??
        DocumentEncoding.utf8,
    newline:
        DocumentNewline.values
            .where((v) => v.name == data['newline'])
            .firstOrNull ??
        DocumentNewline.system,
  );
}

final class FilePreferences {
  bool excludeGeneratedFolders = true;
  bool autoSave = false, recovery = true, restoreWorkspace = false;
  int saveDelay = 2;
  TextFileFormat newDocumentFormat = const TextFileFormat();

  void load(Object? value) {
    if (value is! Map) return;
    autoSave = value['autoSave'] == true;
    recovery = value['recovery'] != false;
    restoreWorkspace = value['restoreWorkspace'] == true;
    excludeGeneratedFolders = value['excludeGeneratedFolders'] != false;
    saveDelay = [2, 5, 10].contains(value['saveDelay'])
        ? value['saveDelay'] as int
        : 2;
    newDocumentFormat = TextFileFormat.fromJson(value);
  }

  Map<String, Object?> toJson() => {
    'autoSave': autoSave,
    'recovery': recovery,
    'restoreWorkspace': restoreWorkspace,
    'excludeGeneratedFolders': excludeGeneratedFolders,
    'saveDelay': saveDelay,
    ...newDocumentFormat.toJson(),
  };
}
