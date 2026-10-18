import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/app.dart';
import 'package:vex/data/repositories/settings_repository.dart';
import 'package:vex/l10n/l10n.dart';
import 'package:vex/ui/workspace/preferences_dialog.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

class _DelayedSettings implements SettingsRepository {
  final pending = <Completer<void>>[];
  @override
  Future<Map<String, Object?>> load() async => {};
  @override
  Future<void> save(Map<String, Object?> value) {
    final result = Completer<void>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  testWidgets('settings footer reports pending writes and failed persistence', (
    tester,
  ) async {
    final settings = _DelayedSettings();
    final vm = WorkspaceViewModel(
      files: MemoryFiles(),
      settings: settings,
      recovery: MemoryRecovery(),
    );
    await tester.pumpWidget(VexApp(viewModel: vm));
    showPreferences(tester.element(find.byType(Scaffold).first), vm);
    await tester.pumpAndSettle();
    vm.updateAppearance(fontSize: 18);
    await tester.pumpAndSettle();
    expect(find.text(vm.strings.prefSaving), findsOneWidget);
    settings.pending.single.completeError(StateError('disk unavailable'));
    await tester.pumpAndSettle();
    expect(find.text(vm.strings.prefSaved), findsNothing);
    expect(vm.preferencesError, contains('disk unavailable'));
    vm.updateAppearance(fontSize: 19);
    settings.pending.last.complete();
    await tester.pumpAndSettle();
    expect(find.text(vm.strings.prefSaved), findsOneWidget);
    expect(vm.preferencesError, isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
  for (final size in [
    const Size(1280, 800),
    const Size(900, 600),
    const Size(650, 750),
    const Size(390, 844),
    const Size(320, 568),
  ]) {
    testWidgets('all preference pages fit $size in every language and theme', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      await tester.pumpWidget(VexApp(viewModel: vm));
      final context = tester.element(find.byType(Scaffold).first);
      for (final language in languageNames.keys) {
        vm.updateAppearance(language: language);
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          vm.updateAppearance(mode: theme);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'workspace before dialog',
          );
          final shown = showPreferences(context, vm);
          await tester.pumpAndSettle();
          final dialog = find.byKey(const ValueKey('preferences-dialog'));
          expect(
            tester.getSize(dialog).width,
            size.width <= 650 ? size.width : 675,
          );
          final header = find.byKey(const ValueKey('preferences-header'));
          final footer = find.byKey(const ValueKey('preferences-footer'));
          for (final category in PreferenceCategory.values) {
            await tester.tap(
              find.byKey(ValueKey('preference-category-${category.name}')),
            );
            await tester.pumpAndSettle();
            final headerBefore = tester.getRect(header),
                footerBefore = tester.getRect(footer);
            expect(find.byType(SingleChildScrollView), findsWidgets);
            final scroll = find.byKey(const ValueKey('preferences-scroll'));
            await tester.drag(scroll, const Offset(0, -700));
            await tester.pumpAndSettle();
            expect(tester.getRect(header), headerBefore);
            expect(tester.getRect(footer), footerBefore);
            expect(
              tester.takeException(),
              isNull,
              reason: '$language / $theme / $category',
            );
            if (size.width <= 650) {
              await tester.tap(find.byTooltip(vm.strings.prefBack));
              await tester.pumpAndSettle();
            }
          }
          Navigator.of(context).pop();
          await tester.pumpAndSettle();
          await shown;
        }
      }
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  }

  testWidgets(
    'preference controls use common aligned widths and preserve typing focus',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vm = fakeWorkspace();
      await tester.pumpWidget(VexApp(viewModel: vm));
      showPreferences(
        tester.element(find.byType(Scaffold).first),
        vm,
        category: PreferenceCategory.mcp,
      );
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(PreferencesDialog),
        matching: find.byType(TextField),
      );
      expect(fields, findsNWidgets(2));
      expect(tester.getSize(fields.first).width, 180);
      expect(
        tester.getRect(fields.first).left,
        tester.getRect(fields.last).left,
      );
      final token = find.descendant(
        of: find.byKey(const ValueKey('mcp-token')),
        matching: find.byType(TextField),
      );
      for (final tooltip in [
        vm.strings.prefMcpReveal,
        vm.strings.mcpGenerate,
      ]) {
        final rect = tester.getRect(find.byTooltip(tooltip));
        final field = tester.getRect(token);
        expect(field.inflate(.1).contains(rect.topLeft), isTrue);
        expect(field.inflate(.1).contains(rect.bottomRight), isTrue);
      }
      await tester.tap(
        find.byKey(const ValueKey('preference-category-images')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(fields, '../outside');
      await tester.pumpAndSettle();
      expect(find.text(vm.strings.prefFolderError), findsOneWidget);
      expect(vm.imagePreferences.folder, 'assets');
      await tester.enterText(fields, 'media/images');
      await tester.pumpAndSettle();
      expect(vm.imagePreferences.folder, 'media/images');
      expect(find.text(vm.strings.prefFolderError), findsNothing);
      expect(
        tester.widget<TextField>(fields).controller!.selection.isValid,
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('preference-category-general')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(vm.strings.prefAutoSave));
      await tester.pumpAndSettle();
      expect(vm.filePreferences.autoSave, isTrue);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );
}
