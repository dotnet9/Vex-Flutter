import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vex/ui/workspace/workspace_mcp.dart';

import 'support/fakes.dart';

// Opt-in integration with the official external CLI, not a substitute HTTP client.
void main() {
  final cli = Platform.environment['VEX_MCP_INSPECTOR_CLI'];
  test(
    'official MCP Inspector discovers and calls Vex tools',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final directory = await Directory.systemTemp.createTemp('vex-inspector-');
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'inspector.md');
      const original =
          '# Inspector\r\n\r\nTest document. 😀\r\n\r\n## Child\r\nBody';
      await File(path).writeAsString(original);
      final files = vm.files as MemoryFiles;
      files.content[path] = original;
      await vm.openPath(path);
      vm.mcp.port = 0;
      await vm.mcp.configure(true);
      Future<Map> inspect(
        String method, {
        String? tool,
        Map<String, Object?>? args,
      }) async {
        final node = Platform.environment['VEX_MCP_NODE'] ?? 'node';
        final arguments = [
          cli!,
          '--cli',
          '--server-url',
          vm.mcp.server.endpoint!,
          '--transport',
          'http',
          '--header',
          'Authorization: Bearer ${vm.mcp.token}',
          '--method',
          method,
          '--format',
          'json',
          '--stored-auth-only',
          if (method == 'tools/list') '--strict',
          if (tool != null) ...['--tool-name', tool],
          if (args != null) ...['--tool-args-json', jsonEncode(args)],
        ];
        final process = await Process.start(
          node,
          arguments,
          environment: {'MCP_INSPECTOR_SECRET_STORE': 'memory'},
        );
        final output = utf8.decoder.bind(process.stdout).join();
        final errors = utf8.decoder.bind(process.stderr).join();
        final code = await process.exitCode.timeout(
          const Duration(seconds: 40),
          onTimeout: () {
            process.kill();
            throw StateError('Inspector timed out');
          },
        );
        await process.stdin.close();
        expect(
          code,
          0,
          reason: 'Inspector failed: ${await errors}\n${await output}',
        );
        return (jsonDecode(await output) as Map)['result'] as Map;
      }

      final list = await inspect('tools/list');
      expect(list['tools'], hasLength(35));
      final covered = <String>{};
      Future<Object?> call(
        String tool, [
        Map<String, Object?> args = const {},
      ]) async {
        final result = await inspect(
          'tools/call',
          tool: 'vex_$tool',
          args: args,
        );
        expect(result['isError'], isNot(true), reason: jsonEncode(result));
        covered.add('vex_$tool');
        return jsonDecode((result['content'] as List).first['text'] as String);
      }

      await inspect('initialize');
      for (final name in [
        'get_document',
        'get_outline',
        'get_selection',
        'list_files',
        'get_app_status',
        'get_operation_audit',
        'ui_get_state',
        'get_capabilities',
        'get_map',
      ]) {
        await call(name);
      }
      expect(
        (await call('read_file', {'path': path}) as Map)['text'],
        original,
      );
      expect(
        (await call('find_text', {'query': 'Test'}) as Map)['matches'],
        hasLength(1),
      );
      vm.mcp.confirm = (_) async => true;
      await call('set_selection', {'start': 0, 'end': 0});
      await call('replace_selection', {'text': 'prefix '});
      await call('insert_text', {'text': '\r\nending'});
      await call('apply_text_edit', {'offset': 0, 'length': 7, 'text': ''});
      await call('replace_text', {'query': 'ending', 'text': 'last line'});
      await call('replace_document', {'text': original});
      final beforeEdits = vm.editor.text;
      await call('apply_edits', {
        'document_id': vm.current.id,
        'revision': vm.editor.session.revision,
        'edits': [
          {'offset': 2, 'length': 9, 'text': 'Verified'},
          {
            'offset': original.indexOf('Body'),
            'length': 4,
            'text': 'Updated body',
          },
        ],
      });
      expect(vm.editor.text, contains('Verified'));
      await call('undo');
      expect(vm.editor.text, beforeEdits);
      await call('redo');
      expect(vm.editor.text, contains('Updated body'));
      String heading() => vm.editor.document.headings.last.id;
      await call('rename_section', {'id': heading(), 'title': 'Renamed'});
      await call('add_section', {
        'id': heading(),
        'child': true,
        'title': 'Nested',
      });
      await call('change_section_level', {'id': heading(), 'delta': -1});
      await call('move_section', {'id': heading(), 'direction': -1});
      await call('delete_section', {'id': heading(), 'keep_contents': true});
      await call('save_document');
      expect(files.content[path], vm.editor.text);
      await call('new_document');
      expect(vm.editor.text, isEmpty);
      vm.mcp.scope = 'custom';
      vm.mcp.customFolder = directory.path;
      await call('open_document', {'path': path});
      expect(vm.current.path, path);
      for (final (name, args) in <(String, Map<String, Object?>)>[
        ('ui_set_layout', {'layout': 'sourceRender'}),
        ('ui_set_theme', {'palette': 'ocean'}),
        ('ui_set_language', {'language': 'en'}),
        ('ui_show_sidebar_tab', {'tab': 'outline'}),
        ('ui_set_theme_mode', {'mode': 'dark'}),
        ('ui_set_typography', {'typography': 'document'}),
        ('set_map_layout', {'layout': 'radial'}),
      ]) {
        await call(name, args);
      }
      expect(covered, WorkspaceMcp.tools.map((tool) => tool['name']).toSet());
      expect(jsonEncode(vm.mcp.audit), isNot(contains(vm.mcp.token)));
    },
    skip: cli == null
        ? 'Set VEX_MCP_INSPECTOR_CLI to the official Inspector CLI entrypoint'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
