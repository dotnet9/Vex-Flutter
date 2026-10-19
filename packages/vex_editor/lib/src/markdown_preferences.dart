import 'package:flutter/foundation.dart';

@immutable
final class MarkdownPreferences {
  const MarkdownPreferences({
    this.math = true,
    this.chemistry = true,
    this.mermaid = true,
    this.subscript = true,
    this.highlight = true,
    this.autoLink = true,
    this.softBreak = true,
  });
  final bool math,
      chemistry,
      mermaid,
      subscript,
      highlight,
      autoLink,
      softBreak;

  // 每次公式匹配都会询问：正则静态化避免反复编译。
  static final RegExp _chemistryRe = RegExp(r'\\(?:ce|pu)\b');

  bool rendersFormula(String source) =>
      _chemistryRe.hasMatch(source) ? chemistry : math;

  MarkdownPreferences copyWith({
    bool? math,
    bool? chemistry,
    bool? mermaid,
    bool? subscript,
    bool? highlight,
    bool? autoLink,
    bool? softBreak,
  }) => MarkdownPreferences(
    math: math ?? this.math,
    chemistry: chemistry ?? this.chemistry,
    mermaid: mermaid ?? this.mermaid,
    subscript: subscript ?? this.subscript,
    highlight: highlight ?? this.highlight,
    autoLink: autoLink ?? this.autoLink,
    softBreak: softBreak ?? this.softBreak,
  );

  Map<String, Object?> toJson() => {
    'math': math,
    'chemistry': chemistry,
    'mermaid': mermaid,
    'subscript': subscript,
    'highlight': highlight,
    'autoLink': autoLink,
    'softBreak': softBreak,
  };

  factory MarkdownPreferences.fromJson(Object? value) => value is! Map
      ? const MarkdownPreferences()
      : MarkdownPreferences(
          math: value['math'] != false,
          chemistry: value['chemistry'] != false,
          mermaid: value['mermaid'] != false,
          subscript: value['subscript'] != false,
          highlight: value['highlight'] != false,
          autoLink: value['autoLink'] != false,
          softBreak: value['softBreak'] != false,
        );
}
