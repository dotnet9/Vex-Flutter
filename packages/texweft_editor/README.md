# texweft_editor

笺纬 Texweft 的独立开源组件。源码位于 `lib/src`，公开接口从 `lib/texweft_editor.dart` 导出。

要求 Dart 3.13 / Flutter 3.47 或更新版本。当前处于开发阶段，尚未发布至 pub.dev。

代码块在阅读与即时编辑中共享原生样式：正常只显示可选择的代码正文；编辑时，语言输入框出现在块下方右侧，没有复制按钮和渲染行号。正文和语言映射到原始 Markdown 围栏，支持中文输入、横向滚动、Ctrl/Cmd+Enter 完成、Esc 恢复和共享撤销历史。源码视图的行号设置独立。

源码与即时编辑的 Enter 支持列表、任务与引用续写，空项退出，粘贴文本块和代码围栏保持原样。即时编辑保留选区两端及 CRLF 映射，点击定位光标，方向键在块首尾切换；ATX 标题回车转入正文。保存时保留正在编辑的块；若保存后按 Esc 回退，文档会正确标记为尚未保存。

Windows 源码视图使用 Re-Editor 0.10.0 的原生按行布局，提供双向滚动和可见行号，避免全文 TextField 的单段排版成本。桥接层保留宿主 `MarkdownEditorController` 接口、原始 UTF-16 选区、未修改部分的混合换行符及共享历史；编辑控件不保留第二套撤销记录。横向与纵向滚动位置按文档分别保留，外部查找选区可滚入视口。剪贴板结果在控件销毁后不会继续写入。

Windows 宿主通过 `DartProject.set_impeller_switch` 使用 Skia：Flutter 3.47.7 的 Impeller GLES 在本机长文档压测中两次发生原生堆损坏。此设置同时覆盖直接启动的安装包和原生测试，后续引擎升级需重新验证后再恢复默认后端。

源码关闭自动换行。向上跳过一屏以上时，使用 Re-Editor 的公开 `forceRepaint` 接口重建可见段落缓存，避免上游逐行排版中间内容；不更改源文、选区或历史。

Android、iOS、macOS、Linux、Web 及其他未验收的平台暂时沿用 Flutter TextField 输入链路。Re-Editor 当前移动端光标有未取消的延迟回调，且平台 delta 输入仍需真机输入法验证；Windows 长文档测试不能代替其他平台性能或中文输入法验收。

即时编辑仍处于完善阶段，跨块拖选、行内语法隐藏、复杂列表与长文档性能尚需继续实现和验证。

组件不携带字体字库。普通正文继承宿主 `TextTheme`；宿主可通过 `ThemeData.extensions` 注入 `MarkdownFontFamilies`，统一书卷衬线、源码及代码字体和各自回退链。例如 `const MarkdownFontFamilies(serif: 'SimSun', monospace: 'MyBundledCodeFont', monospaceFallback: ['Microsoft YaHei UI'])`。字体资源与许可证由宿主负责，默认使用系统 serif／monospace。

国际化由宿主注入 `MarkdownInstantEditor(labels: MarkdownEditorLabels(...))`，包含代码语言的无障碍标签、写作占位提示与新增段落标签；默认使用英语，不依赖 Texweft 的翻译或状态。运行时更换 labels 保留当前输入框、选区与文档历史。`insertTable(columnLabel: (number) => ...)` 支持本地化表头，并选中完整的第一个表头。
