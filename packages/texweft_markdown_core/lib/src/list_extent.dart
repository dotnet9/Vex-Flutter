import 'package:markdown/markdown.dart' as md;

/// Ask CommonMark where the list ends without changing any source offsets.
final class ListExtentParser extends md.BlockParser {
  ListExtentParser(List<String> lines)
    : super(
        lines.map(md.Line.new).toList(),
        md.Document(extensionSet: md.ExtensionSet.gitHubFlavored),
      );

  int _position = 0;

  int? endOfList(int line, {required bool interruptsParagraph}) {
    while (_position < line) {
      advance();
    }
    final syntax = blockSyntaxes
        .whereType<md.ListSyntax>()
        .where((syntax) => syntax.canParse(this))
        .firstOrNull;
    if (syntax == null || (interruptsParagraph && !syntax.canEndBlock(this))) {
      return null;
    }
    syntax.parse(this);
    return _position;
  }

  @override
  void advance() {
    super.advance();
    _position++;
  }

  @override
  void retreat() {
    super.retreat();
    _position--;
  }

  @override
  void retreatBy(int count) {
    super.retreatBy(count);
    _position -= count;
  }
}
