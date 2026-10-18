import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/data/services/file_service.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('large file open, switch, scroll and chapter jump baseline', (
    tester,
  ) async {
    await initializeDesktopWindow(size: const Size(1280, 900));
    final directory = await Directory.systemTemp.createTemp('vex-performance-');
    final sources = <String, String>{};
    for (final chapters in [3000, 120]) {
      final source = StringBuffer('# Document $chapters\n\n');
      for (var i = 0; i < chapters; i++) {
        source.writeln('## Chapter $i\n');
        for (var p = 0; p < 3; p++) {
          source.writeln(
            'Paragraph $i.$p: **Ideas** meet _structure_ with `code($i)` '
            'and [references](https://example.com/$i). '
            'Keep source positions and every idea intact.\n',
          );
        }
      }
      final file = File('${directory.path}/document-$chapters.md');
      sources[file.path] = source.toString();
      await file.writeAsString(source.toString());
    }
    final vm = WorkspaceViewModel(
      files: NativeDocumentFileService(),
      settings: MemorySettings(),
      recovery: MemoryRecovery(),
    );
    await vm.initialize(watchFiles: false);
    vm.setLayout(WorkspaceLayout.read);
    vm.setOutline(true);
    await tester.pumpWidget(VexApp(viewModel: vm, windowIntegration: true));
    await tester.pumpAndSettle();
    final results = <Map<String, Object?>>[];
    final frames = <FrameTiming>[];
    void timings(List<FrameTiming> batch) => frames.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(timings);
    Future<void> measure(String name, FutureOr<void> Function() action) async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      frames.clear();
      final clock = Stopwatch()..start();
      var lastTick = 0, maxGap = 0;
      final heartbeat = Timer.periodic(const Duration(milliseconds: 5), (_) {
        final now = clock.elapsedMicroseconds;
        if (now - lastTick > maxGap) maxGap = now - lastTick;
        lastTick = now;
      });
      await action();
      final actionMs = clock.elapsedMicroseconds / 1000;
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      final wallMs = clock.elapsedMicroseconds / 1000;
      heartbeat.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      double percentile(Iterable<Duration> values, double fraction) {
        final sorted = values.map((v) => v.inMicroseconds).toList()..sort();
        return sorted.isEmpty
            ? 0
            : sorted[((sorted.length - 1) * fraction).round()] / 1000;
      }

      results.add({
        'operation': name,
        'actionMs': actionMs,
        'wallMs': wallMs,
        'eventLoopMaxGapMs': maxGap / 1000,
        'rssMiB': ProcessInfo.currentRss / 1048576,
        'frames': frames.length,
        'buildP95Ms': percentile(frames.map((f) => f.buildDuration), .95),
        'buildMaxMs': percentile(frames.map((f) => f.buildDuration), 1),
        'rasterP95Ms': percentile(frames.map((f) => f.rasterDuration), .95),
        'rasterMaxMs': percentile(frames.map((f) => f.rasterDuration), 1),
        'framesOver16ms': frames
            .where(
              (f) =>
                  f.buildDuration.inMicroseconds > 16667 ||
                  f.rasterDuration.inMicroseconds > 16667,
            )
            .length,
      });
      expect(tester.takeException(), isNull, reason: name);
      expect(vm.editor.text, sources[vm.current.path]);
      expect(vm.editor.session.isDirty, isFalse);
    }

    try {
      for (final path in sources.keys) {
        await measure(
          'open:${path == sources.keys.first ? 'large' : 'small'}',
          () => vm.openPath(path),
        );
      }
      for (var round = 0; round < 3; round++) {
        for (final path in sources.keys) {
          await measure(
            'switch:$round:${path == sources.keys.first ? 'large' : 'small'}',
            () => vm.openPath(path),
          );
        }
      }
      await vm.openPath(sources.keys.first);
      for (final layout in [
        WorkspaceLayout.read,
        WorkspaceLayout.instant,
        WorkspaceLayout.source,
      ]) {
        vm.setLayout(layout);
        await tester.pumpAndSettle();
        for (final index in [2700, 10, 1500]) {
          await measure('jump:${layout.name}:$index', () {
            vm.selectHeading(vm.editor.document.headings[index + 1]);
          });
        }
        await measure('caret:${layout.name}', () async {
          for (var i = 0; i < 20; i++) {
            vm.editor.select(vm.editor.selection.start + 1);
            await tester.pump();
          }
        });
        final scrollable = find
            .descendant(
              of: find.byType(WorkspacePanes),
              matching: find.byType(Scrollable),
            )
            .evaluate()
            .firstWhere(
              (e) =>
                  (e.widget as Scrollable).axisDirection == AxisDirection.down,
            );
        final state = (scrollable as StatefulElement).state as ScrollableState;
        await measure('scroll:${layout.name}', () async {
          for (var i = 0; i < 30; i++) {
            state.position.jumpTo(
              (state.position.pixels + 30).clamp(
                0,
                state.position.maxScrollExtent,
              ),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
        });
      }
      final output = Platform.environment['VEX_LOW_RESOURCE_OUTPUT'];
      final report = {
        'mode': const bool.fromEnvironment('dart.vm.profile')
            ? 'profile'
            : 'debug',
        'os': Platform.operatingSystemVersion,
        'viewport':
            '${tester.view.physicalSize / tester.view.devicePixelRatio}',
        'renderer': 'Windows Skia default backend',
        'documents': [
          for (final text in sources.values)
            {'utf16Length': text.length, 'utf8Bytes': utf8.encode(text).length},
        ],
        'operations': results,
      };
      if (output != null) {
        await File(output).parent.create(recursive: true);
        await File(output)
            .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      }
      debugPrint(jsonEncode(report));
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(timings);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
