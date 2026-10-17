# texweft_mindmap

笺纬 Texweft 的独立开源组件。源码位于 `lib/src`，公开接口从 `lib/texweft_mindmap.dart` 导出。

要求 Dart 3.13 / Flutter 3.47 或更新版本。当前处于开发阶段，尚未发布至 pub.dev。

宿主可通过 `MindMapView(labels: MindMapLabels(...))` 注入缩放、适应画布、展开和折叠的翻译。默认使用英语，与应用资源和语言选择策略解耦。更换 labels 不重置 controller 的缩放、选中与折叠状态。
