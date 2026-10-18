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
import 'package:vex_mindmap/vex_mindmap.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

const _showcase = '''# 写下想法，看见脉络

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

const _mapShowcase = '''# 一篇文章的诞生

## 捕捉灵感

## 收集素材

## 搭建提纲

## 专注写作

## 回看修改

## 导出分享
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture README media from the native Windows application', (
    tester,
  ) async {
    final output = Platform.environment['VEX_CAPTURE_DIR'];
    expect(output, isNotNull, reason: 'Set VEX_CAPTURE_DIR before recording.');
    final directory = Directory(output!);
    await directory.create(recursive: true);
    final framesDirectory = Directory('$output/guide');
    await framesDirectory.create(recursive: true);
    await initializeDesktopWindow(size: const Size(1360, 860));

    final vm = fakeWorkspace();
    await vm.initialize(watchFiles: false);
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content.addAll({
      '/notes/开始写作.md': _showcase,
      '/notes/阅读清单.md': '# 阅读清单\n\n- [ ] 一本好书\n',
      '/notes/技术笔记.md': '# 技术笔记\n\n记录值得回看的细节。\n',
      '/notes/写作流程.md': _mapShowcase,
    });
    await vm.openFolder();
    await vm.openPath('/notes/开始写作.md');
    vm.editor.select(0);
    vm.updateAppearance(fontSize: 18);
    vm.setLayout(WorkspaceLayout.instantMap);
    vm.setSummary(length: 22, lists: false, paragraphs: false);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: VexApp(viewModel: vm, windowIntegration: true),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> resize(Size size) async {
      // window_manager sizes the outer window; keep the captured client exact.
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

    Future<void> capture(String name) async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
      expect(tester.takeException(), isNull, reason: name);
    }

    await resize(const Size(1360, 860));
    await capture('workspace');
    vm.setLayout(WorkspaceLayout.sourceRender);
    await tester.pumpAndSettle();
    await capture('source-preview');

    vm.updateAppearance(mode: ThemeMode.dark);
    await vm.openPath('/notes/写作流程.md');
    vm.setLayout(WorkspaceLayout.map);
    vm.setSummary(mode: MindMapLayoutMode.radial, paragraphs: false);
    vm.setOutline(true);
    await tester.pumpAndSettle();
    await capture('mindmap-dark');

    await vm.openPath('/notes/开始写作.md');
    vm.updateAppearance(mode: ThemeMode.light);
    vm.setOutline(false);
    vm.setLayout(WorkspaceLayout.instant);
    vm.setSummary(mode: MindMapLayoutMode.right, paragraphs: true);
    await resize(const Size(1120, 760));
    final previousText = vm.editor.text;
    final previousLayout = vm.layout;
    final recording = <Map<String, Object>>[];
    var sequence = 0;
    Future<void> frame(int duration) async {
      final name = 'guide/${sequence.toString().padLeft(4, '0')}';
      await capture(name);
      recording.add({'file': '$name.png', 'durationMs': duration});
      sequence++;
    }

    // Capture actual UI transitions as well as readable holds, not mock slides.
    vm.startGuide();
    await tester.pumpAndSettle();
    await frame(3200);
    for (var step = 1; step < 6; step++) {
      await tester.tap(find.text(vm.strings.next).last);
      for (var tick = 0; tick < 6; tick++) {
        await tester.pump(const Duration(milliseconds: 40));
        await frame(40);
      }
      await tester.pumpAndSettle();
      expect(vm.guideStep, step);
      await frame(step == 5 ? 3400 : 3200);
    }
    await tester.tap(find.text(vm.strings.done).last);
    await tester.pumpAndSettle();
    expect(vm.guiding, isFalse);
    expect(vm.editor.text, previousText);
    expect(vm.layout, previousLayout);
    await frame(1600);
    await File('$output/guide-frames.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(recording));
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
