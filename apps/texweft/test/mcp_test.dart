import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:texweft/data/services/mcp_server.dart';

import 'support/fakes.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'MCP settings test authenticates a real server and records no credentials',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.mcp.port = 0;
      await vm.mcp.configure(true);
      addTearDown(vm.mcp.server.stop);
      final configuration = jsonDecode(vm.mcp.clientConfiguration);
      expect(configuration['mcpServers']['vex']['url'], vm.mcp.server.endpoint);
      await vm.mcp.testConnection();
      expect(vm.mcp.audit.first['result'], 'connected');
      expect(jsonEncode(vm.mcp.audit), isNot(contains(vm.mcp.token)));
      vm.mcp.token = 'x' * 32;
      await expectLater(vm.mcp.testConnection(), throwsA(isA<HttpException>()));
      expect(vm.mcp.audit.first['result'], 'connection failed');
      await vm.mcp.configure(false);
      await expectLater(vm.mcp.testConnection(), throwsStateError);
    },
  );
  test(
    'phone platforms never start a persistent MCP server from saved settings',
    () async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        final vm = fakeWorkspace();
        await vm.mcp.load({'enabled': true, 'port': 17891});
        expect(vm.mcp.available, isFalse);
        expect(vm.mcp.enabled, isFalse);
        expect(vm.mcp.server.running, isFalse);
        vm.dispose();
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );
  test('empty startup and a guide never populate the file list', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    await vm.initialize(watchFiles: false);
    expect(vm.documents, isEmpty);
    expect(vm.editor.text, isEmpty);
    vm.startGuide();
    vm.advanceGuide(3);
    vm.endGuide();
    expect(vm.documents, isEmpty);
    expect(vm.editor.text, isEmpty);
    vm.editor.session.replace('我的第一篇文章');
    expect(vm.documents.single, same(vm.current));
    await vm.flushRecovery();
    expect((vm.recovery as MemoryRecovery).value.single['text'], '我的第一篇文章');
  });
  test('MCP rejects unauthenticated and browser requests, exposes real document tools', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.editor.session.replace('# 文档');
    final server = vm.mcp.server, token = McpServer.generateToken();
    await server.start(port: 0, token: token);
    addTearDown(server.stop);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    Future<(int, Object?)> call(
      Map<String, Object?> body, {
      bool auth = true,
      bool origin = false,
    }) async {
      final request = await client.postUrl(Uri.parse(server.endpoint!));
      request.headers.contentType = ContentType.json;
      if (auth) request.headers.set('Authorization', 'Bearer $token');
      if (origin) request.headers.set('Origin', 'https://example.com');
      request.write(jsonEncode(body));
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
    }

    final init = {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {'protocolVersion': '2025-06-18'},
    };
    expect((await call(init, auth: false)).$1, 401);
    expect((await call(init, origin: true)).$1, 403);
    expect(
      ((await call(init)).$2 as Map)['result']['protocolVersion'],
      '2025-06-18',
    );
    final list =
        (await call({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'})).$2
            as Map;
    expect(list['result']['tools'], hasLength(20));
    final read =
        (await call({
              'jsonrpc': '2.0',
              'id': 3,
              'method': 'tools/call',
              'params': {'name': 'texweft_get_document'},
            })).$2
            as Map;
    expect(jsonDecode(read['result']['content'][0]['text'])['text'], '# 文档');
  });
  test('MCP writes require approval and reject a document that changed while waiting', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    vm.editor.session.replace('原文');
    final mcp = vm.mcp;
    await expectLater(
      mcp.dispatch('texweft_replace_document', {'text': '拒绝'}),
      throwsStateError,
    );
    expect(vm.editor.text, '原文');
    final approval = Completer<bool>();
    mcp.confirm = (_) => approval.future;
    final editing = mcp.dispatch('texweft_replace_document', {'text': '过期修改'});
    final expectation = expectLater(editing, throwsStateError);
    vm.editor.session.replace('用户继续输入');
    approval.complete(true);
    await expectation;
    expect(vm.editor.text, '用户继续输入');
    mcp.confirm = (_) async => true;
    await mcp.dispatch('texweft_apply_text_edit', {
      'offset': 0,
      'length': 2,
      'text': '作者',
    });
    expect(vm.editor.text, '作者继续输入');
    vm.editor.session.undo();
    expect(vm.editor.text, '用户继续输入');
    await expectLater(
      mcp.dispatch('texweft_apply_text_edit', {
        'offset': 99,
        'length': 0,
        'text': '',
      }),
      throwsArgumentError,
    );
  });
  test(
    'MCP path scope rejects a symlink or file outside the configured folder',
    () async {
      final temp = await Directory.systemTemp.createTemp('texweft-mcp-test-');
      addTearDown(() => temp.delete(recursive: true));
      final inside = await Directory('${temp.path}/allowed').create();
      final outside = await File('${temp.path}/private.md')
          .writeAsString('private');
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.mcp.requireConfirmation = false;
      vm.mcp.scope = 'custom';
      vm.mcp.customFolder = inside.path;
      await expectLater(
        vm.mcp.dispatch('texweft_open_document', {'path': outside.path}),
        throwsStateError,
      );
      expect(vm.documents, isEmpty);
    },
  );
}
