import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:vex/data/services/mcp_server.dart';

import 'support/fakes.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('HTTP MCP negotiates protocols, rejects invalid transport and rotates credentials', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.editor.session.replace('# 实测\r\n\r\n正文😀');
    final server = vm.mcp.server;
    final token = McpServer.generateToken();
    await server.start(port: 0, token: token);
    final client = _Client(server.endpoint!, token);
    addTearDown(client.close);
    for (final protocol in ['2025-03-26', '2025-06-18', '2025-11-25']) {
      final response = await client.rpc('initialize', {
        'protocolVersion': protocol,
      });
      expect(response.$1, 200);
      expect((response.$2 as Map)['result']['protocolVersion'], protocol);
    }
    expect((await client.rpc('ping')).$1, 200);
    expect((await client.raw('{}', token: 'invalid')).$1, 401);
    expect((await client.raw('{}', origin: 'https://example.com')).$1, 403);
    expect((await client.raw('{}', host: 'example.com')).$1, 403);
    expect((await client.raw('{}', path: '/wrong')).$1, 404);
    expect((await client.raw('', method: 'GET')).$1, 405);
    expect((await client.raw('{}', contentType: 'text/plain')).$1, 415);
    expect((await client.raw('{')).$1, 400);
    expect((await client.raw('{}')).$1, 400);
    expect(((await client.rpc('missing')).$2 as Map)['error']['code'], -32601);
    expect(((await client.rpc('ping', [])).$2 as Map)['error']['code'], -32602);
    expect(
      (await client.raw(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      )).$1,
      202,
    );
    final tools = (await client.rpc('tools/list')).$2 as Map;
    expect(tools['result']['tools'], hasLength(20));
    expect(
      (await client.call('vex_get_document') as Map)['text'],
      vm.editor.text,
    );
    final oversized = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'ping',
      'padding': 'x' * (1024 * 1024),
    });
    expect((await client.raw(oversized)).$1, 413);
    final replacement = McpServer.generateToken();
    await server.start(port: server.port!, token: replacement);
    client.close();
    final reconnected = _Client(server.endpoint!, token);
    addTearDown(reconnected.close);
    expect((await reconnected.rpc('ping')).$1, 401);
    reconnected.token = replacement;
    expect((await reconnected.rpc('ping')).$1, 200);
    await server.stop();
    expect(server.running, isFalse);
    expect(server.endpoint, isNull);
  });

  test('MCP stop cancels an in-flight bind and concurrent restarts leave only one listener', () async {
    final server = McpServer(tools: [], dispatch: (_, _) async => null);
    addTearDown(server.stop);
    final token = McpServer.generateToken();
    final pending = server.start(port: 0, token: token);
    await server.stop();
    await pending;
    expect(server.running, isFalse);
    final first = server.start(port: 0, token: token);
    final second = server.start(port: 0, token: token);
    await Future.wait([first, second]);
    expect(server.running, isTrue);
    final port = server.port!;
    await server.stop();
    final rebound = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await rebound.close();
  });

  test(
    'MCP approval, edits, revision conflicts, undo and audit work over HTTP',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      const source = '# 内容\r\n\r\n正文😀';
      vm.editor.session.replace(source);
      final token = McpServer.generateToken();
      await vm.mcp.server.start(port: 0, token: token);
      final client = _Client(vm.mcp.server.endpoint!, token);
      addTearDown(client.close);
      final denied = await client.call('vex_insert_text', {'text': '禁止'});
      expect(denied, containsPair('isError', true));
      expect(vm.editor.text, source);
      vm.mcp.confirm = (_) async => true;
      final revision = vm.editor.session.revision;
      expect(
        await client.call('vex_insert_text', {
          'text': ' 新增',
          'revision': revision,
        }),
        containsPair('ok', true),
      );
      expect(vm.editor.text, '$source 新增');
      final stale = await client.call('vex_apply_text_edit', {
        'offset': 0,
        'length': 1,
        'text': 'X',
        'revision': revision,
      });
      expect(stale, containsPair('isError', true));
      await client.call('vex_undo');
      expect(vm.editor.text, source);
      await client.call('vex_redo');
      expect(vm.editor.text, '$source 新增');
      final audit = jsonEncode(await client.call('vex_get_operation_audit'));
      expect(audit, contains('vex_insert_text'));
      expect(audit, isNot(contains(source)));
      expect(audit, isNot(contains(token)));
    },
  );

  test(
    'MCP hides out-of-scope filenames and uses the selected folder root',
    () async {
      final directory = await Directory.systemTemp.createTemp('vex-mcp-scope-');
      addTearDown(() async {
        expect(p.isWithin(Directory.systemTemp.path, directory.path), isTrue);
        await directory.delete(recursive: true);
      });
      final root = await Directory(p.join(directory.path, '公开')).create();
      final child = await Directory(p.join(root.path, '子目录')).create();
      final one = await File(p.join(child.path, '一.md')).writeAsString('# 一');
      final two = await File(p.join(root.path, '二.md')).writeAsString('# 二');
      final outside = await File(p.join(directory.path, '私密.md'))
          .writeAsString('# 私密');
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.folderPath = root.path;
      files.content.addAll({
        one.path: '# 一',
        two.path: '# 二',
        outside.path: '# 私密',
      });
      await vm.openPath(one.path);
      await vm.openPath(outside.path);
      expect(await vm.mcp.dispatch('vex_list_files', {}), [
        {'name': vm.current.name, 'path': outside.path},
      ]);
      await vm.openFolder();
      vm.mcp.scope = 'folder';
      vm.mcp.requireConfirmation = false;
      final visible = await vm.mcp.dispatch('vex_list_files', {});
      expect(jsonEncode(visible), contains('一.md'));
      expect(jsonEncode(visible), isNot(contains('私密.md')));
      await vm.mcp.dispatch('vex_open_document', {'path': two.path});
      expect(vm.current.path, two.path);
      await expectLater(
        vm.mcp.dispatch('vex_open_document', {'path': outside.path}),
        throwsStateError,
      );
      await expectLater(
        vm.mcp.dispatch('vex_open_document', {
          'path': p.join(root.path, '..', '私密.md'),
        }),
        throwsStateError,
      );
      await expectLater(
        vm.mcp.dispatch('vex_open_document', {'path': 'relative.md'}),
        throwsArgumentError,
      );
    },
  );

  test(
    'changing MCP access settings or disabling it cancels a pending approval',
    () async {
      for (final disable in [false, true]) {
        final vm = fakeWorkspace();
        vm.editor.session.replace('必须保留');
        final approval = Completer<bool>();
        vm.mcp.confirm = (_) => approval.future;
        final operation = vm.mcp.dispatch('vex_replace_document', {
          'text': '禁止写入',
        });
        final rejected = expectLater(operation, throwsStateError);
        if (disable) {
          await vm.mcp.configure(false);
        } else {
          vm.mcp.scope = 'custom';
          vm.mcp.customFolder = 'changed';
        }
        approval.complete(true);
        await rejected;
        expect(vm.editor.text, '必须保留');
        vm.dispose();
      }
    },
  );

  test('MCP configuration reports port conflicts and shutdown prevents a late restart', () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final vm = fakeWorkspace();
    vm.mcp.port = occupied.port;
    await vm.mcp.configure(true);
    expect(vm.mcp.error, isNotEmpty);
    expect(vm.mcp.server.running, isFalse);
    await occupied.close();
    await vm.mcp.configure(true);
    expect(vm.mcp.server.running, isTrue);
    expect(vm.mcp.error, isEmpty);
    await vm.mcp.configure(false);
    final starting = vm.mcp.configure(true);
    vm.dispose();
    await starting;
    expect(vm.mcp.server.running, isFalse);
  });
}

class _Client {
  _Client(this.endpoint, this.token);
  final String endpoint;
  String token;
  final _client = HttpClient();
  void close() => _client.close(force: true);
  Future<(int, Object?)> raw(
    String body, {
    String? token,
    String? origin,
    String? host,
    String? path,
    String method = 'POST',
    String contentType = 'application/json',
  }) async {
    final uri = Uri.parse(endpoint);
    final request = await _client.openUrl(
      method,
      path == null ? uri : uri.replace(path: path),
    );
    request.headers.set('Authorization', 'Bearer ${token ?? this.token}');
    request.headers.set('Content-Type', contentType);
    if (origin != null) request.headers.set('Origin', origin);
    if (host != null) request.headers.set('Host', host);
    request.add(utf8.encode(body));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  Future<(int, Object?)> rpc(String method, [Object? params]) => raw(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': ?params,
    }),
  );
  Future<Object?> call(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    final response = await rpc('tools/call', {'name': name, 'arguments': args});
    final result = (response.$2 as Map)['result'] as Map;
    return result['isError'] == true
        ? result
        : jsonDecode(result['content'][0]['text'] as String);
  }
}
