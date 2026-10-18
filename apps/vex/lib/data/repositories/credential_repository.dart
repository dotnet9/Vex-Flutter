import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CredentialRepository {
  Future<String?> readMcpToken();
  Future<void> writeMcpToken(String token);
}

final class NativeCredentialRepository implements CredentialRepository {
  NativeCredentialRepository({this.key = 'vex.mcp.token'});
  final String key;
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> readMcpToken() => _storage.read(key: key);
  @override
  Future<void> writeMcpToken(String token) =>
      _storage.write(key: key, value: token);
}
