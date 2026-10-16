/// A fenced code block whose body and language can be edited independently.
/// Untouched whitespace, metadata, fence characters and line endings survive.
final class MarkdownCodeFence {
  MarkdownCodeFence._(
    this._opening,
    this._info,
    this._lineEnding,
    this._closing,
    this._bodyEnding,
    this.code,
  );

  static MarkdownCodeFence? parse(String raw) {
    final opening = RegExp(r'^( {0,3})(`{3,}|~{3,})([^\r\n]*)(\r\n|\n|\r|$)')
        .firstMatch(raw);
    if (opening == null ||
        (opening[2]!.startsWith('`') && opening[3]!.contains('`'))) {
      return null;
    }
    final content = raw.substring(opening.end);
    final closing = RegExp(
      '^ {0,3}${opening[2]![0]}{${opening[2]!.length},}[ \\t]*(?:\\r\\n|\\n|\\r)?\$',
      multiLine: true,
    ).firstMatch(content);
    final body = content.substring(0, closing?.start ?? content.length);
    final ending = RegExp(r'(\r\n|\n|\r)$').firstMatch(body)?.group(0) ?? '';
    return MarkdownCodeFence._(
      '${opening[1]}${opening[2]}',
      opening[3]!,
      opening[4]!,
      closing == null ? '' : content.substring(closing.start),
      ending,
      body.substring(0, body.length - ending.length),
    );
  }

  final String _opening, _info, _lineEnding, _closing, _bodyEnding;
  final String code;

  String get language => RegExp(r'\S+').firstMatch(_info)?.group(0) ?? '';

  /// Offset of the visible code body in the current serialized source.
  int bodyOffset({String? code, String? language}) =>
      _header(code ?? this.code, language ?? this.language).length;

  String _header(String code, String language) {
    final token = RegExp(r'\S+').firstMatch(_info);
    final info = language == this.language
        ? _info
        : token == null
        ? '$_info$language'
        : _info.replaceRange(token.start, token.end, language);
    return '${_fence(code)}$info${_lineEnding.isEmpty ? '\n' : _lineEnding}';
  }

  String _fence(String code) {
    final marker = _opening.trimLeft();
    var size = marker.length;
    for (final match in RegExp(
      '^ {0,3}(${marker[0]}{3,})[ \\t]*\$',
      multiLine: true,
    ).allMatches(code.replaceAll('\r\n', '\n').replaceAll('\r', '\n'))) {
      if (match[1]!.length >= size) size = match[1]!.length + 1;
    }
    return '${_opening.substring(0, _opening.length - marker.length)}${marker[0] * size}';
  }

  String replace({required String code, required String language}) {
    if (language != this.language && RegExp(r'[\s`]').hasMatch(language)) {
      throw ArgumentError.value(
        language,
        'language',
        'Use a single language identifier',
      );
    }
    final ending = _lineEnding.isEmpty ? '\n' : _lineEnding;
    // Flutter edits with LF; a CRLF document keeps its existing convention.
    final normalized = code.replaceAll(RegExp(r'\r\n|\r|\n'), ending);
    if (normalized == this.code && language == this.language) {
      return '$_opening$_info$_lineEnding${this.code}$_bodyEnding$_closing';
    }
    final header = _header(normalized, language);
    final closing = _closing.isEmpty
        ? ''
        : _closing.replaceFirst(
            RegExp(r'`{3,}|~{3,}'),
            _fence(normalized).trimLeft(),
          );
    final separator = _bodyEnding.isNotEmpty
        ? _bodyEnding
        : closing.isNotEmpty && normalized.isNotEmpty
        ? ending
        : '';
    return '$header$normalized$separator$closing';
  }
}
