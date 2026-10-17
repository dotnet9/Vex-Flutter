import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/domain/workspace.dart';
import 'package:texweft/ui/workspace/workspace_view_model.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native large-document switching and scrolling', (tester) async {
    final output = Platform.environment['TEXWEFT_STRESS_OUTPUT'];
    final inputs = Platform.environment['TEXWEFT_STRESS_INPUTS'];
    if (inputs == null || output == null) {
      fail('Set TEXWEFT_STRESS_INPUTS (JSON array) and TEXWEFT_STRESS_OUTPUT.');
    }
    final paths = (jsonDecode(inputs) as List).cast<String>();
    final files = MemoryFiles();
    for (final path in paths) {
      files.content[path] = await File(path).readAsString();
    }
    final vm = WorkspaceViewModel(
      files: files,
      settings: MemorySettings(),
      recovery: MemoryRecovery(),
    );
    await vm.initialize(watchFiles: false);
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1280, 800));
    await tester.pumpWidget(TexweftApp(viewModel: vm));
    await tester.pumpAndSettle();
    final results = <Map<String, Object?>>[];
    String? pending;
    final frames = <FrameTiming>[];
    void timings(List<FrameTiming> values) => frames.addAll(values);
    SchedulerBinding.instance.addTimingsCallback(timings);
    Future<void> persist() async {
      await File(output).parent.create(recursive: true);
      await File(output).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'runtime': Platform.version,
          'os': Platform.operatingSystemVersion,
          'mode': const bool.fromEnvironment('dart.vm.product')
              ? 'release'
              : const bool.fromEnvironment('dart.vm.profile')
              ? 'profile'
              : 'debug',
          'inputs': {
            for (final path in paths) path: files.content[path]!.length,
          },
          'operations': results,
          'pending': pending,
        }),
      );
    }

    Future<void> measure(String name, Future<void> Function() operation) async {
      // Drain the preceding batch of engine frame timings.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      frames.clear();
      pending = name;
      await persist();
      final clock = Stopwatch()..start();
      await operation();
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      clock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final exception = tester.takeException();
      results.add({
        'operation': name,
        'wallMs': clock.elapsedMicroseconds / 1000,
        'rssMiB': ProcessInfo.currentRss / 1048576,
        'frameCount': frames.length,
        'buildMaxMs': frames.isEmpty
            ? null
            : frames
                      .map((f) => f.buildDuration.inMicroseconds)
                      .reduce((a, b) => a > b ? a : b) /
                  1000,
        'rasterMaxMs': frames.isEmpty
            ? null
            : frames
                      .map((f) => f.rasterDuration.inMicroseconds)
                      .reduce((a, b) => a > b ? a : b) /
                  1000,
        if (exception != null) 'error': exception.toString(),
      });
      pending = null;
      await persist();
      expect(exception, isNull, reason: name);
      expect(vm.editor.session.text, files.content[vm.current.path]);
      expect(vm.editor.session.isDirty, isFalse);
    }

    try {
      for (final path in paths) {
        await measure('open:$path', () => vm.openPath(path));
        for (final layout in WorkspaceLayout.values) {
          await measure('layout:${vm.current.name}:${layout.name}', () async {
            vm.setLayout(layout);
          });
          final scrollables = find
              .byType(Scrollable)
              .evaluate()
              .where((element) {
                final widget = element.widget as Scrollable;
                if (widget.axisDirection != AxisDirection.down) return false;
                var nested = false;
                element.visitAncestorElements((ancestor) {
                  if (ancestor.widget case Scrollable(
                    axisDirection: AxisDirection.down,
                  )) {
                    nested = true;
                    return false;
                  }
                  return true;
                });
                if (nested) return false;
                final rect = tester.getRect(find.byWidget(widget));
                return rect.left >= 220 &&
                    rect.height >= 100 &&
                    rect.height < 1000;
              })
              .map((e) => e.widget)
              .toList();
          for (var i = 0; i < scrollables.length; i++) {
            final target = find.byWidget(scrollables[i]);
            if (tester.getSize(target).height < 100) continue;
            await measure(
              'scroll:${vm.current.name}:${layout.name}:$i',
              () async {
                final position = tester.state<ScrollableState>(target).position;
                if (position.maxScrollExtent == 0) return;
                position.jumpTo(0);
                await tester.pump();
                await tester.drag(target, const Offset(0, -420));
                await tester.pumpAndSettle(const Duration(milliseconds: 16));
                expect(
                  position.pixels,
                  greaterThan(0),
                  reason: 'The pane must actually scroll.',
                );
                await tester.drag(target, const Offset(0, 420));
                if (Platform.environment['TEXWEFT_STRESS_DEEP_SCROLL'] == '1') {
                  for (final fraction in [.85, .15, 1.0, 0.0]) {
                    position.jumpTo(position.maxScrollExtent * fraction);
                    await tester.pumpAndSettle(const Duration(milliseconds: 16));
                    expect(position.pixels.isFinite, isTrue);
                  }
                }
              },
            );
          }
        }
      }
      for (var round = 0; round < 3; round++) {
        for (final path in paths.reversed) {
          await measure('switch:$round:$path', () => vm.openPath(path));
          for (final layout in [
            WorkspaceLayout.three,
            WorkspaceLayout.instantMap,
            WorkspaceLayout.sourceRender,
            WorkspaceLayout.instant,
          ]) {
            await measure(
              'repeat:$round:${vm.current.name}:${layout.name}',
              () async => vm.setLayout(layout),
            );
          }
        }
      }
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(timings);
      await persist();
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
