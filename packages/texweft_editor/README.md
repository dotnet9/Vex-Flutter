# texweft_editor

笺纬 Texweft 的独立开源组件。源码位于 `lib/src`，公开接口从 `lib/texweft_editor.dart` 导出。

要求 Dart 3.13 / Flutter 3.47 或更新版本。当前处于开发阶段，尚未发布至 pub.dev。

代码块在阅读与即时编辑中共享原生样式：正常只显示可选择的代码正文；编辑时，语言输入框出现在块下方右侧，没有复制按钮和渲染行号。正文和语言映射到原始 Markdown 围栏，支持中文输入、横向滚动、Ctrl/Cmd+Enter 完成、Esc 恢复和共享撤销历史。源码视图的行号设置独立。
