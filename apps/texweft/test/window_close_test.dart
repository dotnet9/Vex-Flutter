import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/data/repositories/recovery_repository.dart';
import 'package:texweft/ui/workspace/workspace_view_model.dart';

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
    await tester.pumpWidget(TexweftApp(viewModel: vm, windowIntegration: true));
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
  });
}
