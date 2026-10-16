import 'package:texweft_editor/texweft_editor.dart';

enum WorkspaceLayout {
  instant('即时编辑', ['instant']),
  source('源码', ['source']),
  read('阅读', ['read']),
  map('导图', ['map']),
  sourceRender('源码＋渲染', ['source', 'read']),
  sourceMap('源码＋导图', ['source', 'map']),
  instantMap('即时编辑＋导图', ['instant', 'map']),
  three('源码＋渲染＋导图', ['source', 'read', 'map']);

  const WorkspaceLayout(this.label, this.panes);
  final String label;
  final List<String> panes;
}

final class WorkspaceDocument {
  WorkspaceDocument({
    required this.id,
    required this.name,
    required String text,
    this.path,
    this.persistedText,
    this.demo = false,
  }) : editor = MarkdownEditorController(text: text);
  final String id;
  String name;
  String? path, persistedText;
  final bool demo;
  final MarkdownEditorController editor;
  void dispose() => editor.dispose();
}

const welcomeMarkdown = '''# 主题设计笔记

让写作、阅读与结构梳理共享同一份 Markdown，切换视角时保留正在关注的内容。

## 设计原则

### 保持沉浸感

把注意力留给内容。写作时保留必要工具，阅读和梳理结构时让文档占据更多空间。

### 降低视觉噪音

用层级、留白和少量强调色表达关系，避免让边框、按钮和状态提示争夺注意力。

## 主题色体系

主题需要同时照顾浅色与深色。强调色用于选中、定位和主要操作，正文保持稳定对比度。

- 浅色与深色独立选择
- 八套配色共用语义令牌

## 排版与字距

正文以舒适阅读为先，标题层级清晰。导图中的段落默认截取三十个字，点击后可查看完整内容。

## 导出一致性

> 同一份内容，在编辑器、阅读视图与导出文件中，都应该保留清晰的结构。

| 输出格式 | 使用场景 |
| --- | --- |
| HTML | 网页发布 |
| PDF | 阅读与分享 |

```markdown
# 这里是代码，不生成标题节点
```''';

const exampleDocuments = <String, String>{
  '主题设计笔记.md': welcomeMarkdown,
  '每周复盘.md': '# 每周复盘\n\n## 本周进展\n\n- [x] 确认三个主要视图\n- [ ] 收集实际使用反馈\n\n## 下周计划\n\n把结构梳理融入日常 Markdown 写作。',
  '读书摘录.md': '# 读书摘录\n\n## 写作就是思考\n\n写下来，才能看清一个想法里缺失的环节。\n\n> 好的工具应该让想法更清楚。\n\n## 从笔记到文章\n\n### 收集素材\n\n先保留原始材料与出处。\n\n### 整理结构\n\n把相近的观点放在一起，先确定层级，再补充论据。',
  '快速开始.md': '# 快速开始\n\n## 编辑\n\n点击正文直接编辑，或切换源码。所有视图共享同一份内容与撤销历史。\n\n## 阅读\n\n八套配色、六套排版，与内容独立保存。\n\n## 导图\n\n双击节点编辑章节；长按拖到另一个章节可调整层级。\n\n## 本地文件\n\n从文件菜单打开自己的 Markdown。使用 Ctrl+S 保存。未保存内容会保留恢复草稿。',
  '导出指南.md': '# 导出指南\n\n## Markdown\n\n保存为标准 UTF-8 文本，其他编辑器也可继续使用。\n\n## HTML\n\n导出包含当前排版与配色的独立页面。\n\n## PDF 与 Word\n\n导出用于阅读与分享的文档。\n\n## 导图图片\n\n导出完整树形结构的 PNG。',
};
