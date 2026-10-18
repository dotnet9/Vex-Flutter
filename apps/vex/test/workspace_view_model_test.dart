import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:vex_editor/vex_editor.dart';
import 'package:vex_mindmap/vex_mindmap.dart';
import 'package:path/path.dart' as p;
import 'package:vex/data/services/file_service.dart';
import 'package:vex/domain/workspace.dart';

import 'support/fakes.dart';

void main() {
  test('opening a native folder preserves its root, nested files and empty directories', () async {
    final directory = await Directory.systemTemp.createTemp('vex-folder-');
    addTearDown(() async {
      expect(
        directory.absolute.path,
        startsWith(Directory.systemTemp.absolute.path),
      );
      await directory.delete(recursive: true);
    });
    final nested = await Directory('${directory.path}/专题/子目录')
        .create(recursive: true);
    final empty = await Directory('${directory.path}/空目录').create();
    final first = await File('${directory.path}/首篇.md').writeAsString('# 文本');
    final second = await File('${nested.path}/方程.MARKDOWN')
        .writeAsString(r'$$x^2$$');
    final third = await File('${nested.path}/笔记.txt').writeAsString('笔记');
    await File('${nested.path}/图片.svg').writeAsString('<svg/>');
    final folder = await NativeDocumentFileService().readFolder(directory.path);
    expect(folder.path, directory.path);
    expect(
      folder.files.map(p.normalize),
      unorderedEquals([first.path, second.path, third.path].map(p.normalize)),
    );
    expect(
      folder.directories.map(p.normalize),
      containsAll([nested.path, empty.path].map(p.normalize)),
    );
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.folderPath = directory.path;
    files.content.addAll({for (final file in folder.files) file: '# 文档'});
    files.folderDirectories = folder.directories;
    await vm.openFolder();
    expect(vm.folder?.path, directory.path);
    expect(vm.folder?.files, unorderedEquals(folder.files));
    expect(vm.documents, isEmpty);
    files.folderPath = null;
    await vm.openFolder();
    expect(vm.folder?.path, directory.path);
  });

  test(
    'mind map assigns each block to its section with duplicate headings',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.editor.session.replace(
        '# Root\n\nRoot body\n\n## Same\n\nFirst body\n\n### Child\n\nChild body\n\n## Same\n\nSecond body\n',
      );
      final root = vm.map.root;
      expect(root.title, 'Root');
      expect(root.children.map((n) => n.title), ['Root body', 'Same', 'Same']);
      final first = root.children[1], second = root.children[2];
      expect(first.id, isNot(second.id));
      expect(first.children.map((n) => n.title), ['First body', 'Child']);
      expect(first.children.last.children.single.title, 'Child body');
      expect(second.children.single.title, 'Second body');
    },
  );
  test(
    'save marks only the written snapshot as saved when typing continues',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content['/notes/a.md'] = '# 原文';
      await vm.openPath('/notes/a.md');
      vm.editor.session.replace('# 第一版');
      final barrier = Completer<void>();
      files.beforeWrite = () => barrier.future;
      final saving = vm.save();
      await Future<void>.delayed(Duration.zero);
      vm.editor.session.replace('# 第二版');
      barrier.complete();
      expect(await saving, isTrue);
      expect(files.content['/notes/a.md'], '# 第一版');
      expect(vm.editor.session.isDirty, isTrue);
      vm.editor.session.undo();
      expect(vm.editor.session.isDirty, isFalse);
    },
  );
  test('external change is detected and never overwritten silently', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content['/notes/a.md'] = '# 原文';
    await vm.openPath('/notes/a.md');
    vm.editor.session.replace('# 本地修改');
    files.content['/notes/a.md'] = '# 外部修改';
    await vm.checkExternal();
    expect(vm.externalChange?.text, '# 外部修改');
    await expectLater(vm.save(), throwsA(isA<FileConflict>()));
    expect(vm.editor.session.text, '# 本地修改');
    vm.reloadExternal();
    expect(vm.editor.session.isDirty, isFalse);
    vm.editor.session.undo();
    expect(vm.editor.session.text, '# 本地修改');
  });
  test('guided exercise restores original document and undo history', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.editor.session.replace('# 我的内容');
    final original = vm.editor.session.text;
    vm.setLayout(WorkspaceLayout.three);
    vm.sidebar = false;
    vm.outline = false;
    vm.focusMode = true;
    vm.filter = 'existing';
    vm.outlineFilter = 'chapter';
    vm.setMapStyle(MindMapStyle.capsule);
    vm.setSummary(mode: MindMapLayoutMode.balanced);
    vm.map.select(vm.map.root.id);
    vm.map.fit(const Size(500, 400));
    vm.map.zoom(1.5, const Size(500, 400));
    final transform = Matrix4.copy(vm.map.transformation.value);
    final selected = vm.map.selectedId;
    vm.startGuide();
    vm.advanceGuide(1);
    expect(vm.sidebar, isTrue);
    vm.setMapStyle(MindMapStyle.mono);
    vm.setSummary(mode: MindMapLayoutMode.radial);
    vm.updateAppearance(typography: MarkdownTypography.book, compact: true);
    vm.advanceGuide(3);
    vm.editor.session.addHeading(null, child: false);
    vm.endGuide();
    expect(vm.editor.session.text, original);
    expect(vm.layout, WorkspaceLayout.three);
    expect(vm.sidebar, isFalse);
    expect(vm.outline, isFalse);
    expect(vm.focusMode, isTrue);
    expect(vm.filter, 'existing');
    expect(vm.outlineFilter, 'chapter');
    expect(vm.typography, MarkdownTypography.simple);
    expect(vm.compact, isFalse);
    expect(vm.map.style, MindMapStyle.capsule);
    expect(vm.map.mode, MindMapLayoutMode.balanced);
    expect(vm.map.selectedId, selected);
    expect(vm.map.transformation.value, transform);
    vm.editor.session.undo();
    expect(vm.editor.session.text, isEmpty);
  });
  test(
    'saving a guided exercise cannot queue an overwrite after guide ends',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content['/notes/original.md'] = '# Original';
      await vm.openPath('/notes/original.md');
      vm.startGuide();
      final saving = vm.save();
      vm.endGuide();
      expect(await saving, isFalse);
      expect(files.content['/notes/original.md'], '# Original');
    },
  );
  test(
    'recovered drafts preserve the saved comparison and stay dirty',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      (vm.recovery as MemoryRecovery).value = [
        {'name': '草稿.md', 'text': '新内容', 'saved': '旧内容', 'path': '/notes/a.md'},
      ];
      await vm.initialize(watchFiles: false);
      await vm.restoreDrafts();
      expect(vm.editor.session.text, '新内容');
      expect(vm.editor.session.isDirty, isTrue);
      await vm.flushRecovery();
      expect((vm.recovery as MemoryRecovery).value.single['saved'], '旧内容');
    },
  );
  test(
    'native writing keeps existing file intact when a conflict is detected',
    () async {
      final dir = await Directory.systemTemp.createTemp('vex-test-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/note.md');
      await file.writeAsString('外部内容');
      final service = NativeDocumentFileService();
      await expectLater(
        service.write(file.path, '覆盖', expected: '旧内容'),
        throwsA(isA<FileConflict>()),
      );
      expect(await file.readAsString(), '外部内容');
      await service.write(file.path, '新内容', expected: '外部内容');
      expect(await file.readAsString(), '新内容');
      expect(await dir.list().length, 1);
    },
  );
}
