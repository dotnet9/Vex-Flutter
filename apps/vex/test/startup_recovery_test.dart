import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/repositories/recovery_repository.dart';
import 'package:vex/data/repositories/settings_repository.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

class _UnavailableSettings implements SettingsRepository {
  @override
  Future<Map<String, Object?>> load() async => throw StateError('unavailable');
  @override
  Future<void> save(Map<String, Object?> value) async {}
}

class _UnreadableRecovery implements RecoveryRepository {
  var writes = 0;
  @override
  Future<List<Map<String, Object?>>> load() async =>
      throw StateError('unreadable drafts');
  @override
  Future<void> save(List<Map<String, Object?>> documents) async {
    writes++;
  }
}

void main() {
  for (final settings in <String, SettingsRepository>{
    'unavailable settings': _UnavailableSettings(),
    'malformed preference field': MemorySettings()..value = {'fontSize': 'bad'},
  }.entries) {
    test(
      '${settings.key} never hides or overwrites existing recovery drafts',
      () async {
        final recovery = MemoryRecovery()
          ..value = [
            {'name': 'yesterday.md', 'text': 'Precious draft', 'saved': ''},
          ];
        final vm = WorkspaceViewModel(
          files: MemoryFiles(),
          settings: settings.value,
          recovery: recovery,
        );
        addTearDown(vm.dispose);

        await vm.initialize(watchFiles: false);

        expect(vm.ready, isTrue);
        expect(vm.recoverable.single['text'], 'Precious draft');
        expect(vm.filePreferences.autoSave, isFalse);
        expect(vm.notice, vm.strings.preferencesUnavailable);
        vm.editor.session.replace('New draft');
        await vm.flushRecovery(throwOnError: true);
        expect(
          recovery.value.map((d) => d['text']),
          containsAll(['Precious draft', 'New draft']),
        );
        await vm.restoreDrafts();
        expect(
          vm.documents.any((d) => d.editor.text == 'Precious draft'),
          isTrue,
        );
        expect(vm.documents.any((d) => d.editor.text == 'New draft'), isTrue);
      },
    );
  }

  test(
    'failed startup recovery reads block destructive writes and draft close',
    () async {
      final recovery = _UnreadableRecovery();
      final vm = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: MemorySettings(),
        recovery: recovery,
      );
      addTearDown(vm.dispose);
      await vm.initialize(watchFiles: false);
      await vm.flushRecovery(throwOnError: true);
      expect(recovery.writes, 0);
      vm.editor.session.replace('Keep this new draft too');
      final document = vm.current;

      await vm.flushRecovery();
      await expectLater(vm.flushRecovery(throwOnError: true), throwsStateError);
      await expectLater(vm.closeCurrent(keepDraft: true), throwsStateError);

      expect(recovery.writes, 0);
      expect(vm.current, same(document));
      expect(vm.editor.text, 'Keep this new draft too');
      expect(vm.notice, contains('unreadable drafts'));
    },
  );

  test(
    'explicitly disabled draft recovery remains disabled on startup',
    () async {
      final settings = MemorySettings()
        ..value = {
          'files': {'recovery': false},
        };
      final recovery = MemoryRecovery()
        ..value = [
          {'name': 'old.md', 'text': 'Old draft'},
        ];
      final vm = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: settings,
        recovery: recovery,
      );
      addTearDown(vm.dispose);

      await vm.initialize(watchFiles: false);

      expect(vm.recoverable, isEmpty);
      expect(vm.filePreferences.recovery, isFalse);
      expect(recovery.value.single['text'], 'Old draft');
    },
  );
}
