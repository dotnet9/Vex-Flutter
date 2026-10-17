# 笺纬 Texweft 设计原型

笺纬 Texweft · 落笔成文，思路成形。

本目录包含用于评审的 HTML、CSS、JavaScript 和品牌素材。Flutter 应用实现在 `apps/texweft`；原型的版本与第三方许可由实际项目数据生成。安装流程页面仍为设计原型。

## 打开

用现代浏览器直接打开 `design/index.html`。运行资源全部位于本仓库，无需依赖 Vex 仓库、安装依赖、外部字体或 CDN。离线分享时需要保留整个 `design` 目录及仓库根目录 `logo.svg`，保持相对路径。

- `index.html`：桌面、手机、平板及六个平台安装流程的导航。
- `Texweft.html`：桌面工作区，沿用 Vex 原型的布局和主要交互；手机、平板参数自动转到自适应原型。
- `Texweft-Adaptive.html`：手机单页、平板分栏的触控布局。
- `Appearance.html`：八套配色和六套排版，使用同一篇文章连续比较。
- `Texweft-Installer-*.html`：Windows、macOS、Linux、HarmonyOS、Android、iOS 的安装或获取流程。

## Markdown 演示

桌面从视图菜单进入“演示模式”，或按 F5；自适应原型的视图菜单及手机更多菜单也提供入口。标题生成独立页面，`---` 可显式分页；支持大纲直达、前后翻页、Home / End、字号调整与 Esc 退出。长页面可滚动，退出保留原工作区布局和编辑位置。演示不会修改源文。

演示栏提供“正文 / 导图”切换，两者共用当前页和大纲。导图翻页会聚焦对应节点；可平移、缩放或查看全图，点击节点定位章节，双击节点回到正文。演示中不提供节点重排或正文修改。

大图总览在低于 20% 且超过 300 个节点时省略无法辨认的节点文字；放大或聚焦章节恢复完整节点。原生实现此时直接绘制卡片，避免同时创建上千个文字与拖动控件。

程序使用相同的分页规则与四语言控制文案。桌面原生演示进入全屏，退出恢复进入前的窗口状态。浏览器支持时请求全屏，不支持时仍可在窗口内演示。`assets/presentation.js` 与 `assets/presentation.css` 为桌面、自适应原型共用实现。

## 品牌与外观

品牌主色统一称为“品牌墨青”，浅色主色值 `#24766B`。默认外观为纸白背景＋品牌墨青；深色模式使用更明亮的对应强调色。用户选择其他界面配色时，Logo 保持品牌色。

根目录 `logo.svg` 是 Logo 源文件，所有原型都直接引用它。`logo.png` 为 1024×1024 透明背景，`logo.ico` 包含 16、24、32、48、64、128、256 像素尺寸，供未来程序使用。修改 SVG 后应重新生成 PNG / ICO。

八套界面配色：品牌墨青、石墨、海蓝、沙金、蔷薇、鸢尾、橄榄、陶朱。每套均覆盖浅色与深色的背景、文字、边框、按钮及选中状态。旧方案中相近的蓝、青、紫色已合并，用中性灰、玫红和橄榄色补足差异。

原十八套排版合并为六套结构不同的阅读样式：

| 名称 | 用途 | 主要区别 |
| --- | --- | --- |
| 简约 | 日常写作 | 清爽留白，正文色标题 |
| 文档 | 知识整理 | 分节细线，清晰层级 |
| 书卷 | 散文与长读 | 衬线字形、舒展行距、较窄行宽 |
| 技术 | 开发笔记 | 信息块标题，代码边框，较宽正文 |
| 专栏 | 观点文章 | 强标题、侧边标记、独立引用 |
| 刊物 | 发布阅读 | 窄栏、居中节标题、阅读节奏 |

紧凑间距是独立开关，不再作为一套排版重复计数。正文排版与界面配色独立设置，Markdown 内容不因外观切换改变。桌面、手机和平板共享配色及排版定义；HTML 导出带入所选排版。

## 工作区和交互

桌面保留 Vex 的文件与大纲、即时编辑与源码、阅读、导图、章节编排、工具菜单、导出面板、演示和六步引导。固定为单窗口，没有拆出视图或多窗口管理。

八种视图组合：即时编辑、源码、阅读、导图、源码＋渲染、源码＋导图、即时编辑＋导图、源码＋渲染＋导图。三视图上方为源码和渲染，下方为整宽导图。所有视图共用当前文档。

可评审即时编辑、源码联动、Markdown 格式插入、查找替换、撤销重做、文件切换、导图平移缩放与折叠、章节改名和正文编辑、新增与移动章节、升降级、删除、原文恢复和引导演练。Markdown / HTML 可下载为副本；高级导出与部分工具仅展示页面状态。浏览器不会自动写回导入的原文件。

手机保持写作 / 阅读 / 导图单页切换，平板支持分栏；移动与桌面是不同交互原型，尚不代表所有桌面菜单都已有对应触控流程。

代码块参考 Typora：正常显示只有等宽代码正文、浅色背景和细边框，没有语言标签、行号或复制按钮；即时编辑时才在块下方右侧出现语言输入框，失焦或完成编辑后隐藏。正文直接选择并使用系统复制。修改正文或语言同步回 Markdown 围栏；Esc 取消本次块编辑。源码编辑器的行号设置独立保留。

字体策略与原生应用一致：界面／中文使用各平台系统字体及回退链，书卷使用系统宋体；只随应用携带约 0.92 MiB 的 Cascadia Code，原型通过 `assets/fonts.css` 共享 `../apps/texweft/assets/fonts/` 中的两份文件。离线评审应保留这部分目录；没有共享字体时仍可回退到系统等宽字体。应用不额外内嵌 Inter 或完整宋体字库。

## 目录

| 路径 | 内容 |
| --- | --- |
| `../logo.svg / logo.png / logo.ico` | 统一品牌素材 |
| `assets/desktop/` | Vex 桌面原型适配、单窗口工作区及品牌样式 |
| `assets/palettes.js / palettes.css` | 八套配色目录与明暗主题变量 |
| `assets/typography-catalog.js / typography.css` | 六套排版、正文规则及导出样式 |
| `assets/tokens.css` | 导航、移动端与安装流程的基础组件 |
| `assets/app.css / app.js` | 手机和平板布局、示例数据、交互 |
| `assets/editor.js / mindmap.js` | 移动端简化 Markdown 编辑及标题导图 |
| `assets/installer.css / installer.js` | 六个平台安装流程及状态演示 |

## 评审参数

应用支持 `device=desktop|tablet|phone`、`platform=windows|macos|linux|harmonyos|android|ios`、`theme=light|dark|system`、`palette=weft|graphite|ocean|sand|rose|iris|olive|ember`、`typography=Simple|Basic|InkBlack|TechnologyBlue|Column|WeChatFormat`。

桌面布局：`layout=instant|source|read|map|source-render|source-map|instant-map|three`；兼容旧的 `source-read`。手机、平板使用 `source-read` 表示源码＋阅读。`scenario=draft|guide` 打开预设评审场景。桌面语言使用 `lang=zh-CN|zh-Hant|en-US|ja-JP`，移动端 `lang=en` 仅切换主要导航。新增排版名称与部分交互文案尚未全部翻译。

`preview=1` 用于导航页内嵌预览，隔离浏览器持久偏好。普通应用页面只保存显示偏好，文档和撤销记录仍在内存中，刷新恢复示例；草稿恢复是预设场景。

安装流程支持 `theme=dark`、`scenario=installed|error`。异常场景在首次安装中失败，重试可完成。HarmonyOS 增加 `device=phone|tablet|desktop`、`channel=store`；Android 增加 `update=1`；iOS 增加 `channel=testflight`。Linux 包含模拟授权、安装进度、完成、失败重试和移除状态，侧栏和底部操作区在小窗口中保持完整布局。

## 原型边界

所有安装、授权、替换、修复、移除、更新和商店获取都是状态演示，不修改系统。HarmonyOS 手机、平板和电脑页面是概念原型，正式系统界面与分发方式仍需结合设备和 SDK 验证。版本、包名、签名和获取状态不作为实际已发布信息。

浏览器原型用于评审视觉、布局和交互。应用使用 Flutter 原生渲染，单窗口、以本地文件为中心，代码位于 `apps/texweft`；没有引入 SQLite、账户或云同步。复杂 Markdown、中文输入法、大文档与各平台文件访问、导出仍需持续工程验证，预览构建不代表各平台正式安装包已交付。

桌面设计来源：Vex，https://github.com/dotnet9/Vex 。运行代码已复制适配到本仓库，不依赖原仓库路径。

作者：沙漠尽头的狼 / CodeWF · https://codewf.com
