/// Host-provided translations. The reusable editor has no app dependency.
class MarkdownEditorLabels {
  const MarkdownEditorLabels({
    this.codeLanguage = 'Code language',
    this.placeholder = 'Start with your first sentence…',
    this.newParagraph = 'New paragraph',
    this.diagramSource = 'Mermaid source',
    this.diagramPreview = 'Diagram preview',
    this.diagramUnavailable = 'Preview unavailable',
    this.diagramError = 'Invalid diagram syntax. Source preserved.',
  });

  final String codeLanguage, placeholder, newParagraph;
  final String diagramSource, diagramPreview, diagramUnavailable, diagramError;
}
