import 'package:flutter/material.dart';
import 'package:texweft_editor/texweft_editor.dart';

void main() => runApp(const MaterialApp(home: EditorExample()));

class EditorExample extends StatefulWidget {
  const EditorExample({super.key});
  @override
  State<EditorExample> createState() => _EditorExampleState();
}

class _EditorExampleState extends State<EditorExample> {
  final controller = MarkdownEditorController(
    text: '# 原生 Markdown\n\n两侧共享原文和撤销历史。\n',
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Texweft Editor'),
      actions: [
        IconButton(
          onPressed: controller.session.undo,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          onPressed: controller.session.redo,
          icon: const Icon(Icons.redo),
        ),
      ],
    ),
    body: Row(
      children: [
        Expanded(child: MarkdownSourceEditor(controller: controller)),
        const VerticalDivider(width: 1),
        Expanded(child: MarkdownInstantEditor(controller: controller)),
      ],
    ),
  );
}
