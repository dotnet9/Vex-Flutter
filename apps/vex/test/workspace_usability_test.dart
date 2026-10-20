import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_outline.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';
import 'package:vex/ui/workspace/workspace_save_status.dart';
import 'package:vex_editor/vex_editor.dart';

import 'support/fakes.dart';

void main() {
  test(
    'new defaults focus on writing and explicit old preferences survive',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      await vm.initialize(watchFiles: false);
      expect(vm.structure, isFalse);
      expect((vm.paragraphs, vm.lists, vm.blocks), (false, false, false));
      expect(vm.guiding, isFalse);
      (vm.settings as MemorySettings).value = {
        'structure': true,
        'paragraphs': true,
        'lists': true,
      };
      await vm.initialize(watchFiles: false);
      expect(vm.structure, isTrue);
      expect((vm.paragraphs, vm.lists, vm.blocks), (true, true, false));
    },
  );

  test(
    'save status follows a failed write, retry and newer unsaved edits',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content['/notes/a.md'] = '# Saved';
      await vm.openPath('/notes/a.md');
      expect(vm.saveState, vm.strings.diskVersion);
      vm.editor.session.replace('# Draft');
      files.beforeWrite = () async =>
          throw const FileSystemException('disk full');
      await expectLater(vm.save(), throwsA(isA<FileSystemException>()));
      expect(vm.current.saving, isFalse);
      expect(vm.current.saveError, isA<FileSystemException>());
      expect(vm.saveState, vm.strings.saveFailedRetry);
      expect(vm.editor.session.isDirty, isTrue);
      expect(files.content['/notes/a.md'], '# Saved');
      final barrier = Completer<void>();
      files.beforeWrite = () => barrier.future;
      final saving = vm.save();
      expect(vm.saveState, vm.strings.savingDocument);
      await Future<void>.delayed(Duration.zero);
      vm.editor.session.replace('# Newer draft');
      barrier.complete();
      expect(await saving, isTrue);
      expect(vm.current.saveError, isNull);
      expect(vm.current.lastSavedAt, isNotNull);
      expect(vm.saveState, vm.strings.unsavedChanges);
      expect(files.content['/notes/a.md'], '# Draft');
      files.beforeWrite = null;
      await vm.save();
      expect(vm.editor.session.isDirty, isFalse);
      expect(vm.saveState, startsWith('已保存'));
    },
  );

  test('cancelled save and recovery status never claim a disk write', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.newDocument();
    vm.editor.session.replace('你好 **world**');
    (vm.files as MemoryFiles).nextSave = null;
    expect(await vm.save(), isFalse);
    expect(vm.current.path, isNull);
    expect(vm.current.lastSavedAt, isNull);
    expect(vm.editor.session.isDirty, isTrue);
    expect(vm.saveState, vm.strings.newUnsaved);
    await vm.flushRecovery();
    expect(vm.currentDraftSaved, isTrue);
    vm.editor.session.replace('另一版');
    expect(vm.currentDraftSaved, isFalse);
  });

  test(
    'free map selection and explicit return preserve the editing anchor',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.editor.session.replace('# Root\n\n## One\n\nBody\n\n## Two\n\nMore');
      vm.setLayout(WorkspaceLayout.sourceMap);
      vm.editor.select(19);
      final anchor = vm.editor.editingSelection;
      vm.setLinkedViews(false);
      vm.selectNode(vm.map.layout.nodes.values.last);
      expect(vm.editor.navigation.value, isNull);
      vm.selectHeading(vm.editor.document.headings.last);
      expect(vm.editor.navigation.value!.selection.start, greaterThan(19));
      expect(vm.editor.editingSelection, anchor);
      vm.returnToEditing();
      expect(vm.editor.navigation.value!.selection, anchor);
      expect(vm.linkedViews, isFalse);
      expect(vm.editor.viewportLinked, isFalse);
      vm.newDocument();
      expect(vm.editor.viewportLinked, isFalse);
    },
  );

  test('chapter moves reject cycles and H7, include children and undo safely', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    const text =
        '# Root\n\n## A\n\nbody A\n\n### Child\n\nchild body\n\n## B\n\nbody B\n\n###### Deep\n';
    vm.editor.session.replace(text);
    vm.setLayout(WorkspaceLayout.sourceMap);
    String id(String title) =>
        vm.editor.document.headings.firstWhere((h) => h.title == title).id;
    expect(vm.movePreview(id('A'), id('Child')), isNull);
    expect(vm.movePreview(id('A'), id('Deep')), isNull);
    final preview = vm.movePreview(id('A'), id('B'))!;
    expect(preview.level, 3);
    expect(preview.children, 1);
    vm.moveNode(id('A'), id('B'));
    expect(
      vm.editor.text,
      contains('### A\n\nbody A\n\n#### Child\n\nchild body'),
    );
    expect(vm.canUndoChapter, isTrue);
    await vm.save();
    vm.undoChapter();
    expect(vm.editor.text, text);
    expect(
      vm.editor.session.isDirty,
      isTrue,
    ); // The saved disk baseline survives undo.
    vm.moveNode(id('A'), id('B'));
    vm.editor.session.replace('${vm.editor.text}\nA later edit');
    final later = vm.editor.text;
    expect(vm.canUndoChapter, isFalse);
    vm.undoChapter();
    expect(vm.editor.text, later);
  });

  test(
    'word totals and selection exclude Markdown and count mixed scripts',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.editor.session.replace(
        '# 你好 **world**\n\n[Good day](https://example.com)',
      );
      expect(vm.wordCount, 5);
      vm.editor.select(2, 14);
      expect(vm.selectedWordCount, 3);
      vm.setLayout(WorkspaceLayout.read);
      vm.setReadingSelection('你好 Good day');
      expect(vm.selectedWordCount, 4);
    },
  );

  testWidgets(
    'free scrolling leaves other panes still, return stays unlinked',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = fakeWorkspace();
      vm.sidebar = false;
      vm.editor.session.replace(
        List.generate(
          100,
          (i) => '## Section $i\n\n${'Body text. ' * 12}\n\n',
        ).join(),
      );
      vm.setLayout(WorkspaceLayout.sourceRender);
      vm.editor.select(10);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final read = find.byKey(ValueKey('${vm.current.id}-read'));
      ScrollPosition sourcePosition() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(MarkdownSourceEditor),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      await tester.drag(read, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(sourcePosition().pixels, greaterThan(0));
      vm.setLinkedViews(false);
      await tester.pumpAndSettle();
      final sourceBefore = sourcePosition().pixels;
      await tester.drag(read, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(sourcePosition().pixels, closeTo(sourceBefore, .1));
      vm.returnToEditing();
      await tester.pumpAndSettle();
      expect(sourcePosition().pixels, lessThan(sourceBefore));
      expect(vm.linkedViews, isFalse);
      expect(vm.editor.editingSelection.start, 10);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );

  for (final size in [
    const Size(800, 480),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    testWidgets('fixed controls and current article preview fit $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['VEX_VISUAL_OUTPUT'] != null) {
        await tester.runAsync(() async {
          for (final (family, font) in [
            ('Ahem', 'msyh.ttc'),
            ('Roboto', 'msyh.ttc'),
            ('Segoe UI', 'segoeui.ttf'),
            ('Microsoft YaHei UI', 'msyh.ttc'),
            ('SimSun', 'simsun.ttc'),
          ]) {
            await (FontLoader(family)..addFont(
                  Future.value(
                    ByteData.sublistView(
                      await File('C:/Windows/Fonts/$font').readAsBytes(),
                    ),
                  ),
                ))
                .load();
          }
        });
      }
      final vm = fakeWorkspace();
      vm.editor.session.replace(
        '# 当前文章\n\n用户确认的内容 **不能被预览修改**。\n\n## 第二节\n\nHello world',
      );
      vm.setLayout(WorkspaceLayout.three);
      final original = vm.editor.text;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: VexApp(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceOutline), findsNothing);
      expect(vm.sidebarVisible, size.width >= 1100);
      final pane = tester.getRect(find.byType(WorkspacePanes));
      final bar = tester.getRect(
        find.byKey(const ValueKey('document-status-bar')),
      );
      expect(bar.top, greaterThanOrEqualTo(pane.bottom));
      await tester.tap(find.byTooltip(vm.strings.markdownTypography));
      await tester.pumpAndSettle();
      final current = find.byKey(const ValueKey('preview-current-article'));
      expect(tester.widget<ChoiceChip>(current).selected, isTrue);
      await tester.tap(find.byKey(const ValueKey('preview-sample-article')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('preview-sample-article')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(current);
      await tester.pumpAndSettle();
      expect(vm.editor.text, original);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['VEX_VISUAL_OUTPUT'];
      if (output != null) {
        await tester.runAsync(() async {
          await Directory(output).create(recursive: true);
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/usability-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'recovery review identifies files and compares saved and draft text',
    (tester) async {
      final vm = fakeWorkspace();
      (vm.recovery as MemoryRecovery).value = [
        {
          'name': 'Example.md',
          'path': '/notes/Example.md',
          'saved': 'Old sentence',
          'text': 'New sentence',
        },
      ];
      await vm.initialize(watchFiles: false);
      await tester.pumpWidget(VexApp(viewModel: vm));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      final opened = showRecoveryDrafts(context, vm);
      await tester.pumpAndSettle();
      expect(find.textContaining('/notes/Example.md'), findsOneWidget);
      expect(find.text('Old sentence'), findsOneWidget);
      expect(find.text('New sentence'), findsOneWidget);
      await tester.tap(find.text(vm.strings.restore).last);
      await tester.pumpAndSettle();
      await opened;
      expect(vm.current.recovered, isTrue);
      expect(vm.saveState, vm.strings.recoveredNeedsSave);
      expect(vm.editor.session.isDirty, isTrue);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
}
