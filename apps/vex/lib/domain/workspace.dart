import 'package:vex_editor/vex_editor.dart';
import 'package:vex_markdown_core/vex_markdown_core.dart';

import 'file_preferences.dart';

enum FileListMode { tree, list }

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
    required String id,
    required String name,
    required String text,
    String? path,
    String? persistedText,
    bool demo = false,
    TextFileFormat format = const TextFileFormat(),
  }) : this.fromDocument(
         id: id,
         name: name,
         document: MarkdownDocument.parse(text),
         path: path,
         persistedText: persistedText,
         demo: demo,
         format: format,
       );

  WorkspaceDocument.fromDocument({
    required this.id,
    required this.name,
    required MarkdownDocument document,
    this.path,
    this.persistedText,
    this.demo = false,
    this.format = const TextFileFormat(),
  }) : editor = MarkdownEditorController(
         session: MarkdownSession.fromDocument(document),
       );
  final String id;
  String name;
  String? path, persistedText;
  bool saveCopy = false;
  final bool demo;
  TextFileFormat format;
  final MarkdownEditorController editor;
  void dispose() => editor.dispose();
}
