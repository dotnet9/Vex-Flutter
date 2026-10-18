enum ExportPaper { a4, letter, a5 }

final class ExportPreferences {
  const ExportPreferences({
    this.format = 'html',
    this.folder = '',
    this.openAfterExport = true,
    this.paper = ExportPaper.a4,
    this.margin = 20,
    this.htmlStyle = true,
  });
  final String format, folder;
  final bool openAfterExport, htmlStyle;
  final ExportPaper paper;
  final double margin;
  ExportPreferences copyWith({
    String? format,
    String? folder,
    bool? openAfterExport,
    ExportPaper? paper,
    double? margin,
    bool? htmlStyle,
  }) => ExportPreferences(
    format: ['html', 'pdf', 'md', 'docx', 'png'].contains(format)
        ? format!
        : this.format,
    folder: folder ?? this.folder,
    openAfterExport: openAfterExport ?? this.openAfterExport,
    paper: paper ?? this.paper,
    margin: (margin ?? this.margin).clamp(10, 30),
    htmlStyle: htmlStyle ?? this.htmlStyle,
  );
  Map<String, Object?> toJson() => {
    'format': format,
    'folder': folder,
    'open': openAfterExport,
    'paper': paper.name,
    'margin': margin,
    'htmlStyle': htmlStyle,
  };
  factory ExportPreferences.fromJson(Object? value) {
    if (value is! Map) return const ExportPreferences();
    return const ExportPreferences().copyWith(
      format: value['format'] as String?,
      folder: value['folder'] as String?,
      openAfterExport: value['open'] != false,
      paper: ExportPaper.values
          .where((p) => p.name == value['paper'])
          .firstOrNull,
      margin: (value['margin'] as num?)?.toDouble(),
      htmlStyle: value['htmlStyle'] != false,
    );
  }
}

final class WatermarkPreferences {
  const WatermarkPreferences({
    this.preview = false,
    this.export = false,
    this.text = '维刻 Vex',
    this.opacity = .12,
  });
  final bool preview, export;
  final String text;
  final double opacity;
  bool get visible => text.trim().isNotEmpty && opacity > 0;
  WatermarkPreferences copyWith({
    bool? preview,
    bool? export,
    String? text,
    double? opacity,
  }) => WatermarkPreferences(
    preview: preview ?? this.preview,
    export: export ?? this.export,
    text: text == null ? this.text : String.fromCharCodes(text.runes.take(60)),
    opacity: (opacity ?? this.opacity).clamp(0, .5),
  );
  Map<String, Object?> toJson() => {
    'preview': preview,
    'export': export,
    'text': text,
    'opacity': opacity,
  };
  factory WatermarkPreferences.fromJson(Object? value) {
    if (value is! Map) return const WatermarkPreferences();
    return const WatermarkPreferences().copyWith(
      preview: value['preview'] == true,
      export: value['export'] == true,
      text: value['text'] as String?,
      opacity: (value['opacity'] as num?)?.toDouble(),
    );
  }
}
