import 'package:flutter/material.dart';
import 'package:vex_mindmap/vex_mindmap.dart';

void main() => runApp(const MaterialApp(home: MindMapExample()));

class MindMapExample extends StatefulWidget {
  const MindMapExample({super.key});
  @override
  State<MindMapExample> createState() => _MindMapExampleState();
}

class _MindMapExampleState extends State<MindMapExample> {
  final controller = MindMapController(
    const MindMapNode(
      id: 'root',
      title: '旅行计划',
      children: [
        MindMapNode(
          id: 'route',
          title: '路线',
          children: [MindMapNode(id: 'city', title: '目的地')],
        ),
        MindMapNode(id: 'budget', title: '预算'),
      ],
    ),
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vex Mindmap · 通用树形数据')),
    body: MindMapView(controller: controller),
  );
}
