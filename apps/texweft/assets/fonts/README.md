PDF 离线导出字体来自 [Google Fonts 的 Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)，遵循同目录 `OFL.txt`（SIL Open Font License 1.1）。

`NotoSansSC.ttf` 为字重 400 的静态实例，`NotoSansSC-SemiBold.ttf` 为字重 600 的静态实例。使用 FontTools 4.67.0 从 `NotoSansSC[wght].ttf` 生成，未修改字形。重新生成：`python scripts/prepare_export_fonts.py <变量字体路径>`。使用静态实例可避免 PDF 字体解析器把可变字体渲染为默认的极细字重。

字体只用于离线文档导出，不替换应用的系统界面字体。PDF 仅嵌入使用到的字形子集。
