import 'package:flutter/material.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

/// Register grammars only when selected; large blocks keep plain text editing.
abstract final class MarkdownCodeHighlighting {
  static final _engine = Highlight();
  static final languages = <String, Mode>{
    ...builtinLanguages,
    ...builtinCommunityLanguages,
  };
  static final names = (['text', ...languages.keys]..sort());
  static const _labels = {
    'text': 'Plain Text',
    'csharp': 'C#',
    'cpp': 'C++',
    'javascript': 'JavaScript',
    'typescript': 'TypeScript',
    'objectivec': 'Objective-C',
    'xml': 'HTML / XML',
    'shell': 'Shell',
    'powershell': 'PowerShell',
    'fsharp': 'F#',
  };
  static String label(String name) => _labels[name] ?? name;
  static List<String> matching(String query) {
    final key = query.trim().toLowerCase();
    final matches = names
        .where(
          (name) =>
              name.contains(key) ||
              label(name).toLowerCase().contains(key) ||
              (languages[name]?.aliases?.any((alias) => alias.contains(key)) ??
                  false),
        )
        .toList();
    int rank(String name) =>
        name == key ||
            label(name).toLowerCase() == key ||
            (languages[name]?.aliases?.contains(key) ?? false)
        ? 0
        : name.startsWith(key) || label(name).toLowerCase().startsWith(key)
        ? 1
        : 2;
    matches.sort((a, b) {
      final order = rank(a).compareTo(rank(b));
      return order == 0 ? a.compareTo(b) : order;
    });
    return matches.take(30).toList();
  }

  static final _cache = <(String, String, TextStyle?, Brightness), TextSpan>{};
  static String? canonical(String name) {
    final key = name.trim().toLowerCase();
    if (languages.containsKey(key)) return key;
    return languages.entries
        .where((entry) => entry.value.aliases?.contains(key) == true)
        .firstOrNull
        ?.key;
  }

  static Map<String, TextStyle> theme(Brightness brightness) =>
      brightness == Brightness.dark
      ? const {
          'keyword': TextStyle(color: Color(0xffff93b5)),
          'built_in': TextStyle(color: Color(0xffe0bd88)),
          'string': TextStyle(color: Color(0xff9bd3a3)),
          'number': TextStyle(color: Color(0xffe0bd88)),
          'comment': TextStyle(color: Color(0xff9ba6ad)),
          'title': TextStyle(color: Color(0xff92c5ff)),
          'attr': TextStyle(color: Color(0xffd4b7ff)),
          'literal': TextStyle(color: Color(0xffe0bd88)),
        }
      : const {
          'keyword': TextStyle(color: Color(0xffa62657)),
          'built_in': TextStyle(color: Color(0xff805617)),
          'string': TextStyle(color: Color(0xff326a37)),
          'number': TextStyle(color: Color(0xff805617)),
          'comment': TextStyle(color: Color(0xff657179)),
          'title': TextStyle(color: Color(0xff245fa8)),
          'attr': TextStyle(color: Color(0xff7450a2)),
          'literal': TextStyle(color: Color(0xff805617)),
        };
  static TextSpan span(
    String code,
    String language,
    TextStyle? style,
    Brightness brightness,
  ) {
    final name = canonical(language);
    if (name == null || code.length > 32768) {
      return TextSpan(text: code, style: style);
    }
    final key = (code, name, style, brightness);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    if (_engine.getLanguage(name) == null) {
      _engine.registerLanguage(name, languages[name]!);
    }
    try {
      final result = _engine.highlight(code: code, language: name);
      final renderer = TextSpanRenderer(style, theme(brightness));
      result.render(renderer);
      final span = renderer.span ?? TextSpan(text: code, style: style);
      _cache[key] = span;
      if (_cache.length > 24) _cache.remove(_cache.keys.first);
      return span;
    } catch (_) {
      return TextSpan(text: code, style: style);
    }
  }
}
