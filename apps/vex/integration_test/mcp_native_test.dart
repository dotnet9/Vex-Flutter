import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/data/repositories/credential_repository.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native secure credentials persist and authenticate MCP without touching the user token',
    (tester) async {
      final key = 'vex.test.mcp.${DateTime.now().microsecondsSinceEpoch}';
      final credentials = NativeCredentialRepository(key: key);
      addTearDown(() => const FlutterSecureStorage().delete(key: key));
      final vm = WorkspaceViewModel(
        files: MemoryFiles(),
        settings: MemorySettings(),
        recovery: MemoryRecovery(),
        credentials: credentials,
      );
      addTearDown(vm.dispose);
      vm.mcp.port = 0;
      await vm.mcp.configure(true);
      expect(vm.mcp.error, isEmpty);
      expect(vm.mcp.server.running, isTrue);
      expect(
        await NativeCredentialRepository(key: key).readMcpToken(),
        vm.mcp.token,
      );
      await vm.mcp.testConnection();
      final old = vm.mcp.token;
      vm.mcp.token = 'test-rotated-${DateTime.now().microsecondsSinceEpoch}';
      await vm.mcp.configure(true);
      expect(await credentials.readMcpToken(), vm.mcp.token);
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.postUrl(Uri.parse(vm.mcp.server.endpoint!));
      request.headers.set('Authorization', 'Bearer $old');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}));
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 401);
      await vm.mcp.testConnection();
      await vm.mcp.configure(false);
      expect(vm.mcp.server.running, isFalse);
    },
    skip: !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux,
  );
}
