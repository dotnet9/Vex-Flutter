import 'package:flutter/foundation.dart';

enum MarkdownBodyFont { system, serif, mono }

@immutable
final class MarkdownEditingPreferences {
  const MarkdownEditingPreferences({
    this.font = MarkdownBodyFont.system,
    this.codeSize = 13,
    this.indent = 2,
    this.autoPair = true,
    this.codeWrap = false,
  });
  final MarkdownBodyFont font;
  final double codeSize;
  final int indent;
  final bool autoPair, codeWrap;

  MarkdownEditingPreferences copyWith({
    MarkdownBodyFont? font,
    double? codeSize,
    int? indent,
    bool? autoPair,
    bool? codeWrap,
  }) => MarkdownEditingPreferences(
    font: font ?? this.font,
    codeSize: (codeSize ?? this.codeSize).clamp(11, 20),
    indent: [2, 4, 8].contains(indent) ? indent! : this.indent,
    autoPair: autoPair ?? this.autoPair,
    codeWrap: codeWrap ?? this.codeWrap,
  );

  Map<String, Object?> toJson() => {
    'font': font.name,
    'codeSize': codeSize,
    'indent': indent,
    'autoPair': autoPair,
    'codeWrap': codeWrap,
  };
  factory MarkdownEditingPreferences.fromJson(Object? value) {
    if (value is! Map) return const MarkdownEditingPreferences();
    return const MarkdownEditingPreferences().copyWith(
      font: MarkdownBodyFont.values
          .where((v) => v.name == value['font'])
          .firstOrNull,
      codeSize: value['codeSize'] is num
          ? (value['codeSize'] as num).toDouble()
          : null,
      indent: value['indent'] is int ? value['indent'] as int : null,
      autoPair: value['autoPair'] != false,
      codeWrap: value['codeWrap'] == true,
    );
  }
}
