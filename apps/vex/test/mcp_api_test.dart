import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vex/data/repositories/credential_repository.dart';
import 'package:vex/ui/workspace/workspace_mcp.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('every published MCP tool has documentation and a closed schema', () {
    final root = Directory.current.path.endsWith('${p.separator}vex')
        ? '../..'
        : '.';
    final reference = File(p.join(root, 'docs/mcp/MCP工具接口.md'))
        .readAsStringSync();
    for (final tool in WorkspaceMcp.tools) {
      expect(reference, contains('`${tool['name']}`'));
      expect((tool['inputSchema'] as Map)['additionalProperties'], isFalse);
      expect(tool['annotations'], containsPair('openWorldHint', false));
    }
    expect(
      WorkspaceMcp.tools.map((tool) => tool['name']).toSet(),
      hasLength(35),
    );
  });

  test('batch patches are atomic, revision checked and UTF-16 safe', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.mcp.requireConfirmation = false;
    const original = '# 中文\r\n\r\nA😀B';
    vm.editor.session.replace(original);
    Map<String, Object?> patches(List<Map<String, Object?>> edits) => {
      'document_id': vm.current.id,
      'revision': vm.editor.session.revision,
      'edits': edits,
    };
    final emoji = original.indexOf('😀');
    for (final edits in [
      [
        {'offset': emoji + 1, 'length': 0, 'text': 'x'},
      ],
      [
        {'offset': emoji, 'length': 1, 'text': 'x'},
      ],
      [
        {'offset': 0, 'length': 2, 'text': 'x'},
        {'offset': 1, 'length': 0, 'text': 'y'},
      ],
      [
        {'offset': 0, 'length': 0, 'text': 'x'},
        {'offset': 0, 'length': 0, 'text': 'y'},
      ],
    ]) {
      await expectLater(
        vm.mcp.dispatch('vex_apply_edits', patches(edits)),
        throwsArgumentError,
      );
      expect(vm.editor.text, original);
    }
    await vm.mcp.dispatch(
      'vex_apply_edits',
      patches([
        {'offset': emoji, 'length': 2, 'text': '🌱'},
        {'offset': 2, 'length': 2, 'text': '标题'},
      ]),
    );
    expect(vm.editor.text, '# 标题\r\n\r\nA🌱B');
    vm.editor.session.undo();
    expect(vm.editor.text, original);
    await expectLater(
      vm.mcp.dispatch('vex_insert_text', {'offset': emoji + 1, 'text': 'x'}),
      throwsArgumentError,
    );
    await expectLater(
      vm.mcp.dispatch('vex_set_selection', {'start': 5, 'end': 2}),
      throwsArgumentError,
    );
    await expectLater(
      vm.mcp.dispatch('vex_insert_text', {'text': 'x', 'document_id': 'other'}),
      throwsStateError,
    );
    await expectLater(
      vm.mcp.dispatch('vex_get_document', {'revision': -1}),
      throwsStateError,
    );
  });

  test('MCP rejects schema violations before dispatching changes', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.mcp.requireConfirmation = false;
    for (final (tool, args) in <(String, Map<String, Object?>)>[
      ('insert_text', {'text': 7}),
      ('insert_text', {'text': 'x', 'unknown': true}),
      ('list_files', {'limit': 1001}),
      ('list_files', {'offset': -1}),
      ('ui_set_layout', {'layout': 'invalid'}),
      ('ui_set_theme', {'palette': 'invalid'}),
      (
        'apply_edits',
        {'edits': [], 'revision': 0, 'document_id': vm.current.id},
      ),
      (
        'apply_edits',
        {
          'edits': [
            {'offset': 0, 'length': -1, 'text': ''},
          ],
          'revision': 0,
          'document_id': vm.current.id,
        },
      ),
    ]) {
      await expectLater(
        vm.mcp.dispatch('vex_$tool', args),
        throwsArgumentError,
      );
    }
    expect(vm.editor.text, isEmpty);
  });

  test(
    'new document scoped tools cannot operate on out-of-scope content',
    () async {
      final directory = await Directory.systemTemp.createTemp('vex-mcp-api-');
      addTearDown(() => directory.delete(recursive: true));
      final allowed = await Directory(p.join(directory.path, 'allowed'))
          .create();
      final outside = await File(p.join(directory.path, 'private.md'))
          .writeAsString('# Private');
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      (vm.files as MemoryFiles).content[outside.path] = '# Private';
      await vm.openPath(outside.path);
      vm.mcp.scope = 'custom';
      vm.mcp.customFolder = allowed.path;
      vm.mcp.requireConfirmation = false;
      final id = vm.editor.document.headings.single.id;
      for (final (name, args) in <(String, Map<String, Object?>)>[
        ('find_text', {'query': 'Private'}),
        ('get_map', {}),
        ('set_selection', {'start': 0, 'end': 1}),
        ('rename_section', {'id': id, 'title': 'Bad'}),
        ('add_section', {'title': 'Bad'}),
        ('delete_section', {'id': id}),
        ('move_section', {'id': id, 'direction': 1}),
        ('change_section_level', {'id': id, 'delta': 1}),
        (
          'apply_edits',
          {
            'document_id': vm.current.id,
            'revision': vm.editor.session.revision,
            'edits': [
              {'offset': 0, 'length': 0, 'text': 'Bad'},
            ],
          },
        ),
      ]) {
        await expectLater(vm.mcp.dispatch('vex_$name', args), throwsStateError);
      }
      expect(vm.editor.text, '# Private');
      final secret = await File(p.join(allowed.path, 'secret.json'))
          .writeAsString('secret');
      await expectLater(
        vm.mcp.dispatch('vex_read_file', {'path': secret.path}),
        throwsArgumentError,
      );
      expect(
        vm.mcp.audit.every((entry) => entry['result'] == 'declined or failed'),
        isTrue,
      );
    },
  );

  test(
    'switching documents during async read or open discards the result',
    () async {
      for (final action in ['read_file', 'open_document']) {
        final directory = await Directory.systemTemp.createTemp(
          'vex-mcp-race-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = p.join(directory.path, 'document.md');
        await File(path).writeAsString('# One');
        final vm = fakeWorkspace();
        addTearDown(vm.dispose);
        final files = vm.files as MemoryFiles;
        files.content[path] = '# One';
        vm.mcp.requireConfirmation = false;
        vm.mcp.scope = 'custom';
        vm.mcp.customFolder = directory.path;
        final waiting = Completer<void>(), release = Completer<void>();
        files.beforeRead = (_) async {
          waiting.complete();
          await release.future;
        };
        final request = vm.mcp.dispatch('vex_$action', {'path': path});
        final denied = expectLater(request, throwsStateError);
        await waiting.future;
        vm.newDocument();
        final current = vm.current;
        release.complete();
        await denied;
        expect(vm.current, same(current));
        expect(vm.editor.text, isEmpty);
      }
    },
  );

  test(
    'credential failures fail closed and never persist tokens in preferences',
    () async {
      for (final silentlyDiscard in [false, true]) {
        final settings = MemorySettings();
        final vm = WorkspaceViewModel(
          files: MemoryFiles(),
          recovery: MemoryRecovery(),
          settings: settings,
          credentials: _UnavailableCredentials(silentlyDiscard),
        );
        addTearDown(vm.dispose);
        vm.mcp.port = 0;
        await vm.mcp.configure(true);
        expect(vm.mcp.enabled, isFalse);
        expect(vm.mcp.server.running, isFalse);
        expect(vm.mcp.error, isNotEmpty);
        expect(vm.mcp.preferences, isNot(contains('token')));
        expect(settings.value.toString(), isNot(contains(vm.mcp.token)));
      }
    },
  );
}

class _UnavailableCredentials implements CredentialRepository {
  _UnavailableCredentials(this.silentlyDiscard);
  final bool silentlyDiscard;
  @override
  Future<String?> readMcpToken() async => null;
  @override
  Future<void> writeMcpToken(String token) async {
    if (!silentlyDiscard) throw StateError('Unavailable');
  }
}
