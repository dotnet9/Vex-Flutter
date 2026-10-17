界面与中文正文使用系统字体，不向系统安装字体，也不额外打包 Inter、思源宋体等完整字库。Windows 优先 Segoe UI／微软雅黑，Apple 平台使用系统字体／苹方，Android 使用系统 Roboto 与中文回退，Linux 复用已安装的 Noto／系统字库。书卷排版优先系统宋体；缺少衬线中文字形时回退到可用的系统中文字体，因此各平台字形允许有合理差别。

代码内嵌 [Cascadia Code v2407.24](https://github.com/microsoft/cascadia-code/releases/tag/v2407.24)，两份静态字重 400／600 合计约 0.92 MiB，遵循 `CascadiaCode-OFL.txt`。原型通过 `design/assets/fonts.css` 引用同一份字体；源码、行内代码、渲染与编辑代码块均复用它，中文仍使用系统回退。源文件版本与 SHA256 见 `sources.json`。重建：`python scripts/prepare_app_fonts.py <包含 cascadiacode.ttf 和 cascadiacode-OFL.txt 的目录>`，需要 FontTools。

PDF 离线导出字体来自 [Google Fonts 的 Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)，遵循同目录 `OFL.txt`（SIL Open Font License 1.1）。

`NotoSansSC.ttf` 为字重 400 的静态实例，`NotoSansSC-SemiBold.ttf` 为字重 600 的静态实例。使用 FontTools 4.67.0 从 `NotoSansSC[wght].ttf` 生成，未修改字形。重新生成：`python scripts/prepare_export_fonts.py <变量字体路径>`。使用静态实例可避免 PDF 字体解析器把可变字体渲染为默认的极细字重。

Noto Sans SC 只用于离线 PDF 导出，不替换应用界面字体。两份完整静态字体约 20.2 MiB，是当前安装资源中的主要字体开销，后续需单独优化；不能把导出时的字形子集嵌入误说成安装包已经裁剪。PDF 文件仅嵌入使用到的字形子集。
