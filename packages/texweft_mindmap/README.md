# texweft_mindmap

笺纬 Texweft 的独立开源组件。源码位于 `lib/src`，公开接口从 `lib/texweft_mindmap.dart` 导出。

要求 Dart 3.13 / Flutter 3.47 或更新版本。当前处于开发阶段，尚未发布至 pub.dev。

宿主可通过 `MindMapView(labels: MindMapLabels(...))` 注入缩放、适应画布、展开和折叠的翻译。默认使用英语，与应用资源和语言选择策略解耦。更换 labels 不重置 controller 的缩放、选中与折叠状态。

`controller.focusNode(id, viewport)` 展开目标节点的祖先，并以可读倍率将节点居中；`fit(viewport)` 完整适配大图，不再受 15% 缩放下限限制。`enableKeyboardNavigation: false` 可将方向键交还给宿主，例如演示翻页。

超过 300 节点的大图在低于 20% 时绘制简化卡片，放大后恢复文字、折叠和拖动控件；总览仍支持节点点击与双击回调。`overviewThreshold: 0` 可让自定义 `nodeBuilder` 在所有倍率下保持启用。
