/// Host-provided translations. The reusable editor has no app dependency.
class MarkdownEditorLabels {
  const MarkdownEditorLabels({
    this.codeLanguage = 'Code language',
    this.placeholder = 'Start with your first sentence…',
    this.newParagraph = 'New paragraph',
  });

  final String codeLanguage, placeholder, newParagraph;
}
