import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_mindmap/vex_mindmap.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

/// 官网（vex.codewf.com）落地页用的真实界面录制。
///
/// 与 `readme_capture_test.dart` 同源：真实 `VexApp`、真实布局与视图切换，
/// 内存文件替身（不读个人笔记、不写用户配置、不启动 MCP）。
/// 产物是逐帧 PNG + 时长清单，交给 `scripts/docs/encode_gifs.py` 编码成
/// `docs/media/*.gif`，文档站同步脚本会把这些 GIF 复制上线。
///
/// 运行（Windows，仓库根目录）：
///   $env:VEX_CAPTURE_DIR = "$PWD/artifacts/site-capture"
///   cd apps/vex
///   flutter test --no-pub integration_test/site_media_capture_test.dart -d windows
///   cd ../..
///   python scripts/docs/encode_gifs.py artifacts/site-capture

const _viewsDoc = '''# 写下想法，看见脉络

从一段文字开始，把零散的灵感整理成清晰的文章。

## 捕捉灵感

记录读书笔记、技术方案，或今天突然想到的一句话。

- [x] 写下第一个想法
- [x] 整理文章的章节
- [ ] 分享给未来的自己

## 梳理结构

正文与导图共享同一份 **Markdown**。在导图里调整章节，文字也随之变化。

专心写作，也能随时退后一步，看见整篇文章。

## 分享作品

| 格式 | 用途 |
| --- | --- |
| PDF / Word | 交付与分享 |
| HTML / PNG | 发布与展示 |

文件留在本地，用熟悉的文件夹管理。
''';

const _mapDoc = '''# 一篇文章的诞生

## 捕捉灵感

## 收集素材

## 搭建提纲

## 专注写作

## 回看修改

## 导出分享
''';

const _formulaDoc = '''# 公式与化学表达式

## 行内公式

质能关系 \$E = mc^2\$，欧拉恒等式 \$e^{i\\pi} + 1 = 0\$。

## 块公式

\$\$
P = \\sum_{i=1}^{n} \\frac{x_i \\cdot w_i}{\\sigma}
\$\$

\$\$
\\int_{0}^{\\infty} e^{-x^2} \\, dx = \\frac{\\sqrt{\\pi}}{2}
\$\$

## 矩阵

\$\$
\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}
\\qquad
\\begin{bmatrix} 1 & 0 \\\\ 0 & 1 \\end{bmatrix}
\$\$

## 化学表达式

\$\$\\ce{2H2 + O2 -> 2H2O}\$\$

\$\$\\ce{CO2 + H2O -> H2CO3}\$\$
''';

const _mermaidDoc = '''# Mermaid 图表

## 流程图

```mermaid
flowchart LR
    想法 --> 提纲 --> 写作 --> 检查 --> 完成
    检查 --> 修改 --> 写作
```

## 时序图

```mermaid
sequenceDiagram
    用户->>编辑器: 输入正文
    编辑器->>文档模型: 保留源码
    文档模型->>导图: 同步章节
    导图-->>用户: 显示结构
```

## 甘特图

```mermaid
gantt
    title 一篇长文的写作安排
    dateFormat YYYY-MM-DD
    section 准备
    收集素材 :a1, 2026-01-01, 3d
    搭建提纲 :a2, after a1, 2d
    section 成稿
    写作     :b1, after a2, 5d
    检查修改 :b2, after b1, 2d
```
''';

const _appearanceDoc = '''# 同一篇文章，不同外观

正文排版与界面配色独立设置，Markdown 内容不因外观切换改变。

## 配色

八套配色：品牌墨青、石墨、海蓝、沙金、蔷薇、鸢尾、橄榄、陶朱。

## 排版

六套排版：简约、文档、书卷、技术、专栏、刊物。

> 选择只影响显示，不影响磁盘上的 Markdown 文件。

| 项目 | 说明 |
| --- | --- |
| 配色 | 界面与强调色 |
| 排版 | 正文宽度与标题样式 |
| 字号 | 正文大小 |
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture site media from the real Windows application', (
    tester,
  ) async {
    final output = Platform.environment['VEX_CAPTURE_DIR'];
    expect(output, isNotNull, reason: 'Set VEX_CAPTURE_DIR before recording.');
    final directory = Directory(output!);
    await directory.create(recursive: true);
    await initializeDesktopWindow(size: const Size(1360, 860));

    final vm = fakeWorkspace();
    await vm.initialize(watchFiles: false);
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content.addAll({
      '/notes/开始写作.md': _viewsDoc,
      '/notes/写作流程.md': _mapDoc,
      '/notes/公式与化学.md': _formulaDoc,
      '/notes/图表.md': _mermaidDoc,
      '/notes/外观.md': _appearanceDoc,
    });
    await vm.openFolder();
    await vm.openPath('/notes/开始写作.md');
    vm.editor.select(0);
    vm.updateAppearance(fontSize: 18);

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> resize(Size size) async {
      for (var attempt = 0; attempt < 3; attempt++) {
        final client = tester.view.physicalSize / tester.view.devicePixelRatio;
        final outer = await windowManager.getSize();
        await windowManager.setSize(
          Size(
            outer.width + size.width - client.width,
            outer.height + size.height - client.height,
          ),
        );
        await tester.pumpAndSettle();
      }
      final actual = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(actual.width, closeTo(size.width, 2));
      expect(actual.height, closeTo(size.height, 2));
    }

    Future<void> capture(String path) async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/$path.png')
            .writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
      // 切换视图时偶发「构建期间 setState」的一次性提示，不影响画面，
      // 但会污染下一帧；这里清掉它，真正的渲染错误仍会让截图失败。
      tester.takeException();
    }

    final recordings = <String, List<Map<String, Object>>>{};
    var current = '';
    var sequence = 0;

    Future<void> startSet(String name) async {
      current = name;
      sequence = 0;
      recordings[name] = [];
      await Directory('$output/$name').create(recursive: true);
    }

    Future<void> frame(int durationMs) async {
      final path = '$current/${sequence.toString().padLeft(4, '0')}';
      await capture(path);
      recordings[current]!.add({'file': '$path.png', 'durationMs': durationMs});
      sequence++;
    }

    /// 录一次真实切换：先抓过渡动画的逐帧，再停留便于阅读。
    Future<void> transition(VoidCallback change, {int hold = 2400}) async {
      change();
      for (var tick = 0; tick < 6; tick++) {
        await tester.pump(const Duration(milliseconds: 40));
        await frame(40);
      }
      await tester.pumpAndSettle();
      await frame(hold);
    }

    /// 当前可见的正文滚动区（工作区面板里的纵向 Scrollable，排除大纲与侧栏）。
    ScrollableState? contentScrollable() {
      final states = find
          .byType(Scrollable)
          .evaluate()
          .where((element) {
            final widget = element.widget as Scrollable;
            if (widget.axisDirection != AxisDirection.down) return false;
            var inPane = false, nested = false;
            element.visitAncestorElements((ancestor) {
              if (ancestor.widget is WorkspacePanes) inPane = true;
              if (ancestor.widget is Scrollable &&
                  (ancestor.widget as Scrollable).axisDirection ==
                      AxisDirection.down) {
                nested = true;
              }
              return true;
            });
            if (!inPane || nested) return false;
            final size = tester.getSize(find.byWidget(widget));
            return size.height >= 120 && size.width >= 240;
          })
          .map((e) => (e as StatefulElement).state as ScrollableState)
          .toList();
      // 多栏时取最靠左的正文栏（源码栏），它是内容最长的一栏。
      return states.isEmpty ? null : states.first;
    }

    /// 把正文平滑滚到指定进度并逐帧记录，用于展示公式与图表。
    Future<void> scrollTo(
      double fraction, {
      int steps = 10,
      int hold = 900,
    }) async {
      final scrollable = contentScrollable();
      if (scrollable == null) return;
      final position = scrollable.position;
      final from = position.pixels;
      final to = (position.maxScrollExtent * fraction).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        // easeOutCubic，接近真人滚动的收尾
        final eased = 1 - (1 - t) * (1 - t) * (1 - t);
        position.jumpTo(from + (to - from) * eased);
        await tester.pump(const Duration(milliseconds: 30));
        await frame(30);
      }
      await tester.pumpAndSettle();
      await frame(hold);
    }

    await resize(const Size(1360, 860));

    // 1. 四种视图：即时编辑 → 即时编辑＋导图 → 源码 → 阅读 → 导图
    await startSet('views-instant');
    vm.setLayout(WorkspaceLayout.instant);
    await tester.pumpAndSettle();
    await frame(2200);
    await transition(
      () => vm.setLayout(WorkspaceLayout.instantMap),
      hold: 2400,
    );

    await startSet('views-source');
    await transition(() => vm.setLayout(WorkspaceLayout.source), hold: 2200);

    await startSet('views-read');
    await transition(() => vm.setLayout(WorkspaceLayout.read), hold: 2400);

    await startSet('views-mindmap');
    vm.setSummary(mode: MindMapLayoutMode.radial, paragraphs: true);
    await transition(() => vm.setLayout(WorkspaceLayout.map), hold: 2600);

    // 2. 导图六种结构依次切换
    await startSet('mindmap-structures');
    await vm.openPath('/notes/写作流程.md');
    vm.setLayout(WorkspaceLayout.map);
    vm.setSummary(length: 20, paragraphs: false, lists: false);
    await tester.pumpAndSettle();
    await frame(2000);
    for (final mode in MindMapLayoutMode.values) {
      if (mode == MindMapLayoutMode.right) continue;
      await transition(() => vm.setSummary(mode: mode), hold: 2000);
    }

    // 3. 公式、矩阵与化学表达式：阅读栏滚动展示渲染结果
    await startSet('markdown-formulas');
    await vm.openPath('/notes/公式与化学.md');
    vm.setLayout(WorkspaceLayout.read);
    await tester.pumpAndSettle();
    await frame(1800);
    await scrollTo(0.35, hold: 1600); // 行内公式与块公式
    await scrollTo(0.62, hold: 1800); // 矩阵
    await scrollTo(0.88, hold: 1800); // 化学表达式

    // 4. Mermaid 图表：源码＋预览栏滚动展示图表渲染
    await startSet('markdown-mermaid');
    await vm.openPath('/notes/图表.md');
    vm.setLayout(WorkspaceLayout.sourceRender);
    await tester.pumpAndSettle();
    await frame(1800);
    await scrollTo(0.3, hold: 1800); // 流程图
    await scrollTo(0.58, hold: 1800); // 时序图
    await scrollTo(0.85, hold: 1800); // 甘特图

    // 5. 配色与排版
    await startSet('appearance-themes');
    await vm.openPath('/notes/外观.md');
    vm.setLayout(WorkspaceLayout.read);
    await tester.pumpAndSettle();
    await frame(1600);
    for (final palette in ['graphite', 'ocean', 'sand', 'weft']) {
      await transition(() => vm.updateAppearance(palette: palette), hold: 1800);
    }
    for (final typography in [
      MarkdownTypography.book,
      MarkdownTypography.technical,
      MarkdownTypography.simple,
    ]) {
      await transition(
        () => vm.updateAppearance(typography: typography),
        hold: 1800,
      );
    }

    // 6. 深色与多栏
    await startSet('export-formats');
    await vm.openPath('/notes/开始写作.md');
    vm.setLayout(WorkspaceLayout.read);
    await tester.pumpAndSettle();
    await frame(1600);
    await transition(
      () => vm.updateAppearance(mode: ThemeMode.dark),
      hold: 2000,
    );
    await transition(() => vm.setLayout(WorkspaceLayout.three), hold: 2200);
    await transition(
      () => vm.updateAppearance(mode: ThemeMode.light),
      hold: 1600,
    );

    for (final entry in recordings.entries) {
      await File(
        '$output/${entry.key}-frames.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(entry.value));
      stdout.writeln('${entry.key}: ${entry.value.length} frames');
    }
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
