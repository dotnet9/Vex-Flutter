import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/services/desktop_window.dart';
import 'package:vex/domain/workspace.dart';
import 'package:vex/ui/workspace/workspace_panes.dart';
import 'package:vex/ui/workspace/workspace_presentation.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native large-document switching and scrolling', (tester) async {
    final output = Platform.environment['VEX_STRESS_OUTPUT'];
    final inputs = Platform.environment['VEX_STRESS_INPUTS'];
    if (inputs == null || output == null) {
      fail('Set VEX_STRESS_INPUTS (JSON array) and VEX_STRESS_OUTPUT.');
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
    await initializeDesktopWindow();
    await tester.pumpWidget(VexApp(viewModel: vm, windowIntegration: true));
    await tester.pumpAndSettle();
    // The Windows runner shows its first frame with SW_SHOWNORMAL. Maximize
    // afterwards so startup cannot silently restore the test window.
    await windowManager.show();
    await windowManager.maximize();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(await windowManager.isMaximized(), isTrue);
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    final rounds =
        int.tryParse(Platform.environment['VEX_STRESS_ROUNDS'] ?? '') ?? 6;
    final results = <Map<String, Object?>>[];
    var testCompleted = false;
    String? testFailure;
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
          'window': {
            'titleBar': 'custom',
            'maximized': await windowManager.isMaximized(),
            'outerWidth': (await windowManager.getSize()).width,
            'outerHeight': (await windowManager.getSize()).height,
            'viewportWidth': viewport.width,
            'viewportHeight': viewport.height,
            'devicePixelRatio': tester.view.devicePixelRatio,
          },
          'switchRounds': rounds,
          'testCompleted': testCompleted,
          'testFailure': ?testFailure,
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
      Object? failure;
      StackTrace? failureStack;
      try {
        await operation();
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      }
      clock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final exception = tester.takeException() ?? failure;
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
      if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
      expect(exception, isNull, reason: name);
      expect(vm.editor.session.text, files.content[vm.current.path]);
      expect(vm.editor.session.isDirty, isFalse);
      expect(await windowManager.isMaximized(), isTrue, reason: name);
    }

    Future<void> scrollPanes(String label, {bool deep = true}) async {
      final scrollables = find
          .byType(Scrollable)
          .evaluate()
          .where((element) {
            final widget = element.widget as Scrollable;
            if (widget.axisDirection != AxisDirection.down) return false;
            var inPane = false, nested = false;
            element.visitAncestorElements((ancestor) {
              if (ancestor.widget is WorkspacePanes ||
                  ancestor.widget is WorkspacePresentation) {
                inPane = true;
              }
              if (ancestor.widget case Scrollable(
                axisDirection: AxisDirection.down,
              )) {
                nested = true;
              }
              return true;
            });
            // Presentation outline is navigation, not document content.
            var isOutline = false;
            element.visitAncestorElements((ancestor) {
              if (ancestor.widget.key ==
                  const ValueKey('presentation-outline')) {
                isOutline = true;
              }
              return true;
            });
            if (isOutline) return false;
            return inPane &&
                !nested &&
                tester.getSize(find.byWidget(widget)).height >= 100;
          })
          .map((e) => (e as StatefulElement).state as ScrollableState)
          .toList();
      for (var i = 0; i < scrollables.length; i++) {
        final scrollable = scrollables[i];
        // The Scrollable widget object can be replaced after a native focus or
        // layout rebuild; its mounted State is the stable pane identity.
        final target = find.byElementPredicate(
          (element) => identical(element, scrollable.context),
        );
        await measure('scroll:$label:$i', () async {
          expect(scrollable.mounted, isTrue, reason: label);
          final position = scrollable.position;
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
          if (deep && Platform.environment['VEX_STRESS_DEEP_SCROLL'] == '1') {
            for (final fraction in [.85, .15, 1.0, 0.0]) {
              position.jumpTo(position.maxScrollExtent * fraction);
              await tester.pumpAndSettle(const Duration(milliseconds: 16));
              expect(position.pixels.isFinite, isTrue);
            }
          }
        });
      }
    }

    Future<void> present(String label) async {
      final layout = vm.layout, selection = vm.editor.selection;
      await measure(
        'present:$label:enter',
        () async => vm.togglePresentation(),
      );
      final presenter = vm.presenter!;
      for (final fraction in [.0, .5, 1.0, .0]) {
        await measure('present:$label:page:$fraction', () async {
          presenter.goTo(
            ((presenter.deck.slides.length - 1) * fraction).round(),
          );
        });
      }
      await measure('present:$label:zoom', () async => presenter.resize(2.5));
      await scrollPanes('presentation:$label');
      await measure('present:$label:map', () async => presenter.showMap(true));
      await measure('present:$label:map-fit', () async {
        presenter.map.fit(presenter.mapViewport);
      });
      expect(
        presenter.map.layout.size.width * presenter.map.scale,
        lessThanOrEqualTo(presenter.mapViewport.width),
      );
      expect(
        presenter.map.layout.size.height * presenter.map.scale,
        lessThanOrEqualTo(presenter.mapViewport.height),
      );
      for (final fraction in [.5, 1.0, .0]) {
        await measure('present:$label:map-focus:$fraction', () async {
          presenter.goTo(
            ((presenter.deck.slides.length - 1) * fraction).round(),
          );
        });
      }
      await measure('present:$label:map-pan-zoom', () async {
        final canvas = find.byKey(const ValueKey('presentation-map-canvas'));
        await tester.dragFrom(
          tester.getTopLeft(canvas) + const Offset(30, 30),
          const Offset(-240, 120),
        );
        presenter.map.zoom(1.15, presenter.mapViewport);
      });
      await measure(
        'present:$label:markdown',
        () async => presenter.showMap(false),
      );
      await measure('present:$label:exit', () async => vm.togglePresentation());
      expect(vm.layout, layout);
      expect(vm.editor.selection, selection);
    }

    try {
      for (final path in paths) {
        await measure('open:$path', () => vm.openPath(path));
        for (final layout in WorkspaceLayout.values) {
          await measure('layout:${vm.current.name}:${layout.name}', () async {
            vm.setLayout(layout);
          });
          await scrollPanes('${vm.current.name}:${layout.name}');
        }
        await present(vm.current.name);
      }
      for (var round = 0; round < rounds; round++) {
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
            if (round.isOdd) {
              await scrollPanes(
                'repeat:$round:${vm.current.name}:${layout.name}',
              );
            }
          }
          if (round.isEven) await present('repeat:$round:${vm.current.name}');
        }
      }
      testCompleted = true;
    } catch (error) {
      testFailure = error.toString();
      rethrow;
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(timings);
      await persist();
      await windowManager.setPreventClose(false);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 24)));
}
