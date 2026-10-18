import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/repositories/recovery_repository.dart';
import 'package:vex/data/services/file_service.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

class _Recovery implements RecoveryRepository {
  bool fail = false;
  List<Map<String, Object?>> value = [];
  @override
  Future<List<Map<String, Object?>>> load() async => value;
  @override
  Future<void> save(List<Map<String, Object?>> documents) async {
    if (fail) throw StateError('测试：草稿写入失败');
    value = documents;
  }
}

void main() {
  for (final save in [true, false]) {
    testWidgets(
      'window stays open when typing continues during ${save ? 'save all' : 'draft flush'}',
      (tester) async {
        tester.view.physicalSize = const Size(1392, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <MethodCall>[];
        const channel = MethodChannel('window_manager');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            return call.method == 'isMaximized' ? false : null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final vm = fakeWorkspace();
        final files = vm.files as MemoryFiles;
        files.content['/notes/test.md'] = 'saved';
        vm.acceptOpened(
          const OpenedDocument('test.md', 'saved', '/notes/test.md'),
        );
        vm.filePreferences.recovery = !save;
        vm.setLayout(WorkspaceLayout.source);
        vm.editor.session.replace('before closing');
        final entered = Completer<void>(), release = Completer<void>();
        Future<void> blockWrite() async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        }

        if (save) {
          files.beforeWrite = blockWrite;
        } else {
          (vm.recovery as MemoryRecovery).beforeSave = blockWrite;
        }
        await tester.pumpWidget(VexApp(viewModel: vm, windowIntegration: true));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(vm.strings.close));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(save ? vm.strings.saveAll : vm.strings.keepDraftClose),
        );
        await tester.pump();
        expect(entered.isCompleted, isTrue);
        vm.editor.session.replace('continued typing');
        release.complete();
        await tester.pumpAndSettle();
        expect(calls.where((call) => call.method == 'close'), isEmpty);
        expect(vm.editor.text, 'continued typing');
        expect(vm.editor.session.isDirty, isTrue);
        expect(find.textContaining(vm.strings.closeChanged), findsWidgets);
        files.beforeWrite = null;
        (vm.recovery as MemoryRecovery).beforeSave = null;
        await tester.tap(find.byTooltip(vm.strings.close));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(save ? vm.strings.saveAll : vm.strings.keepDraftClose),
        );
        await tester.pumpAndSettle();
        expect(calls.where((call) => call.method == 'close'), hasLength(1));
        if (save) {
          expect(files.content['/notes/test.md'], 'continued typing');
        } else {
          expect(
            (vm.recovery as MemoryRecovery).value.single['text'],
            'continued typing',
          );
        }
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('close can cancel, retry, preserve drafts and use native close', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1392, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <MethodCall>[];
    const channel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'isMaximized') return false;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final recovery = _Recovery();
    final vm = WorkspaceViewModel(
      files: MemoryFiles(),
      settings: MemorySettings(),
      recovery: recovery,
    );
    vm.editor.session.replace('# 关闭测试草稿');
    vm.setLayout(WorkspaceLayout.source);
    await tester.pumpWidget(VexApp(viewModel: vm, windowIntegration: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(vm.strings.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text(vm.strings.cancel));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'close'), isEmpty);

    recovery.fail = true;
    await tester.tap(find.byTooltip(vm.strings.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text(vm.strings.keepDraftClose));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'close'), isEmpty);
    expect(find.textContaining('草稿写入失败'), findsWidgets);

    recovery.fail = false;
    await tester.tap(find.byTooltip(vm.strings.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text(vm.strings.keepDraftClose));
    await tester.pumpAndSettle();
    expect(recovery.value.single['text'], '# 关闭测试草稿');
    expect(calls.where((c) => c.method == 'destroy'), isEmpty);
    final close = calls.indexWhere((c) => c.method == 'close');
    expect(close, greaterThan(0));
    expect(calls[close - 1].method, 'setPreventClose');
    expect(calls[close - 1].arguments, {'isPreventClose': false});
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
