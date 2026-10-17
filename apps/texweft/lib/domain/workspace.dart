import 'package:texweft_editor/texweft_editor.dart';

import 'file_preferences.dart';

enum WorkspaceViewport {
  phone(1),
  tablet(2),
  desktop(3);

  const WorkspaceViewport(this.maxPanes);
  final int maxPanes;

  static WorkspaceViewport forWindow({
    required double width,
    required double height,
    required bool desktop,
  }) {
    if (width < 700 || (!desktop && (width < 600 || height < 600))) {
      return phone;
    }
    return desktop ? WorkspaceViewport.desktop : tablet;
  }
}

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

  WorkspaceLayout constrainedTo(WorkspaceViewport viewport) {
    if (panes.length <= viewport.maxPanes) return this;
    if (viewport == WorkspaceViewport.tablet) return sourceRender;
    return values.firstWhere(
      (layout) => layout.panes.length == 1 && layout.panes.first == panes.first,
    );
  }
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
