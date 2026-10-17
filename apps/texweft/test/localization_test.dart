import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft/app.dart';
import 'package:texweft/domain/workspace.dart';
import 'package:texweft/l10n/l10n.dart';
import 'package:texweft/ui/workspace/insert_table_dialog.dart';
import 'package:texweft/ui/workspace/workspace_dialogs.dart';
import 'package:texweft/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

void main() {
  test('all supported locales have complete nonempty ARB resources', () {
    Set<String>? expected;
    for (final language in languageNames.keys) {
      final arb = jsonDecode(
        File('lib/l10n/app_$language.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final keys = arb.keys.where((key) => !key.startsWith('@')).toSet();
      expected ??= keys;
      expect(keys, expected, reason: language);
      for (final key in keys) {
        expect(arb[key], isA<String>());
        expect(
          (arb[key] as String).trim(),
          isNotEmpty,
          reason: '$language/$key',
        );
      }
    }
  });
  test('system locale resolves Chinese script and region before fallback', () {
    for (final locale in [
      const Locale('zh', 'TW'),
      const Locale('zh', 'HK'),
      const Locale('zh', 'MO'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      expect(languageForLocale(locale), 'zh_Hant');
    }
    expect(languageForLocale(const Locale('zh', 'CN')), 'zh');
    expect(languageForLocale(const Locale('zh', 'SG')), 'zh');
    expect(
      languageForLocale(
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'HK',
        ),
      ),
      'zh',
    );
    expect(languageForLocale(const Locale('ja', 'JP')), 'ja');
    expect(languageForLocale(const Locale('en', 'GB')), 'en');
    expect(languageForLocale(const Locale('fr', 'FR')), 'en');
    expect(languageForLocales(const [Locale('fr'), Locale('ja')]), 'ja');
    expect(languageForLocales(const []), 'en');
  });

  test(
    'switching language preserves document, selection, undo and recovery',
    () async {
      final settings = MemorySettings();
      final recovery = MemoryRecovery();
      final vm = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: settings,
        recovery: recovery,
      );
      await vm.initialize(watchFiles: false);
      final original = vm.editor.text;
      const text = '# 我的文章 / My note / 私の文書\r\n\r\n繁體內容';
      vm.editor.session.replace(text);
      vm.editor.select(text.length - 4, text.length);
      final selection = vm.editor.selection;
      final name = vm.current.name;
      vm.search('[', regex: true);
      for (final language in languageNames.keys) {
        vm.updateAppearance(language: language);
        expect(vm.editor.text, text);
        expect(vm.current.name, name);
        expect(vm.editor.selection, selection);
        expect(vm.editor.session.canUndo, isTrue);
        expect(vm.findError, stringsForLanguage(language).invalidRegex);
      }
      await vm.flushRecovery();
      expect(recovery.value.single['text'], text);
      vm.editor.session.undo();
      expect(vm.editor.text, original);
      vm.dispose();
      final restored = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: settings,
        recovery: MemoryRecovery(),
        initialLanguage: 'en',
      );
      await restored.initialize(watchFiles: false);
      expect(restored.language, 'ja');
      expect(restored.current.name, stringsForLanguage('ja').sampleDesignName);
      expect(restored.editor.text, stringsForLanguage('ja').sampleDesign);
      restored.dispose();
    },
  );

  test(
    'status messages and inserted table headers follow current language',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.newDocument();
      vm.updateAppearance(language: 'en');
      vm.editor.insertTable(
        rows: 2,
        columns: 2,
        columnLabel: vm.strings.tableColumn,
      );
      expect(vm.editor.selection.textInside(vm.editor.text), 'Column 1');
      expect(await vm.save(), isTrue);
      expect(vm.status, startsWith('Saved '));
      vm.updateAppearance(language: 'ja');
      expect(vm.status, endsWith('を保存しました'));
      expect(vm.editor.text, contains('Column 1'));
    },
  );

  for (final size in [
    const Size(1280, 800),
    const Size(900, 700),
    const Size(390, 844),
  ]) {
    for (final language in languageNames.keys) {
      testWidgets('$language workspace, dialogs, pickers and guide fit $size', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final vm = WorkspaceViewModel(
          files: MemoryFiles(),
          settings: MemorySettings(),
          recovery: MemoryRecovery(),
          initialLanguage: language,
        );
        final l = vm.strings;
        await tester.pumpWidget(TexweftApp(viewModel: vm));
        await tester.pumpAndSettle();
        expect(
          Localizations.localeOf(tester.element(find.byType(Scaffold).first)),
          localeForLanguage(language),
        );
        final layouts = size.width < 700
            ? [
                WorkspaceLayout.instant,
                WorkspaceLayout.read,
                WorkspaceLayout.map,
              ]
            : WorkspaceLayout.values;
        for (final layout in layouts) {
          vm.setLayout(layout);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: layout.name);
        }
        vm.setLayout(WorkspaceLayout.instant);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(l.workspaceLayout));
        await tester.pumpAndSettle();
        expect(find.text(l.workspaceLayout), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip(l.closePicker));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Scaffold).first);
        for (final open in <Future<void> Function()>[
          () => showSettings(context, vm),
          () => showAppearance(context, vm),
          () => showSummarySettings(context, vm),
          () => showExportDialog(context, vm),
          () => showAbout(context),
          () async {
            await showInsertTableDialog(context);
          },
        ]) {
          final future = open();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          Navigator.of(context).pop();
          await tester.pumpAndSettle();
          await future;
        }
        vm.startGuide();
        for (var step = 0; step < 6; step++) {
          vm.advanceGuide(step);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'guide $step');
        }
        vm.endGuide();
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
      });
    }
  }

  testWidgets('settings changes language immediately and keeps its selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = fakeWorkspace();
    await tester.pumpWidget(TexweftApp(viewModel: vm));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    final shown = showSettings(context, vm);
    await tester.pumpAndSettle();
    for (final language in ['en', 'zh_Hant', 'ja', 'zh']) {
      await tester.tap(find.byKey(const ValueKey('language-setting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(languageNames[language]!).last);
      await tester.pumpAndSettle();
      expect(vm.language, language);
      expect(find.text(vm.strings.settings), findsOneWidget);
      expect(find.text(vm.strings.languageHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await shown;
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
