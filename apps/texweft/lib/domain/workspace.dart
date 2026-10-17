import 'package:texweft_editor/texweft_editor.dart';

import 'file_preferences.dart';

enum WorkspaceLayout {
  instant(['instant']),
  source(['source']),
  read(['read']),
  map(['map']),
  sourceRender(['source', 'read']),
  sourceMap(['source', 'map']),
  instantMap(['instant', 'map']),
  three(['source', 'read', 'map']);

  const WorkspaceLayout(this.panes);
  final List<String> panes;
}

final class WorkspaceDocument {
  WorkspaceDocument({
    required this.id,
    required this.name,
    required String text,
    this.path,
    this.persistedText,
    this.demo = false,
    this.format = const TextFileFormat(),
  }) : editor = MarkdownEditorController(text: text);
  final String id;
  String name;
  String? path, persistedText;
  final bool demo;
  TextFileFormat format;
  final MarkdownEditorController editor;
  void dispose() => editor.dispose();
}
