import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'mcp_arguments.dart';

/// Stateless Streamable HTTP MCP. All document access is supplied by the host.
/// No browser origin, remote bind address or unauthenticated call is accepted.
final class McpServer {
  McpServer({required this.tools, required this.dispatch});
  final List<Map<String, Object?>> tools;
  final Future<Object?> Function(String name, Map<String, Object?> arguments)
  dispatch;
  HttpServer? _server;
  int _generation = 0;
  String _token = '';
  bool get running => _server != null;
  int? get port => _server?.port;
  String? get endpoint => port == null ? null : 'http://127.0.0.1:$port/mcp/';
  static String generateToken() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  Future<void> start({required int port, required String token}) async {
    if (port < 0 || port > 65535 || token.length < 24) {
      throw ArgumentError('Invalid port or token');
    }
    final generation = ++_generation;
    await _closeServer();
    if (generation != _generation) return;
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: false,
    );
    if (generation != _generation) {
      await server.close(force: true);
      return;
    }
    _token = token;
    _server = server;
    server.listen((request) => unawaited(_handle(request)), onError: (_) {});
  }

  Future<void> stop() async {
    _generation++;
    await _closeServer();
  }

  Future<void> _closeServer() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  bool _authorized(String? header) {
    final expected = 'Bearer $_token', actual = header ?? '';
    var different = expected.length ^ actual.length;
    for (var i = 0; i < expected.length; i++) {
      different |=
          expected.codeUnitAt(i) ^
          (i < actual.length ? actual.codeUnitAt(i) : 0);
    }
    return different == 0;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    try {
      final host = request.headers.value(HttpHeaders.hostHeader);
      if (request.headers.value('Origin') != null ||
          (host != '127.0.0.1:${request.connectionInfo?.localPort}' &&
              host != 'localhost:${request.connectionInfo?.localPort}')) {
        response.statusCode = 403;
        return;
      }
      if (!_authorized(
        request.headers.value(HttpHeaders.authorizationHeader),
      )) {
        response.statusCode = 401;
        return;
      }
      if (!['/mcp', '/mcp/'].contains(request.uri.path)) {
        response.statusCode = 404;
        return;
      }
      if (request.method != 'POST') {
        response.statusCode = 405;
        response.headers.set('Allow', 'POST');
        return;
      }
      if (request.headers.contentType?.mimeType != 'application/json') {
        response.statusCode = 415;
        return;
      }
      final bytes = <int>[];
      await for (final chunk in request.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > 1024 * 1024) {
          response.statusCode = 413;
          response.persistentConnection = false;
          // Send the rejection before cancelling the incoming body stream;
          // cancellation can close its socket before finally gets to close().
          await response.close();
          return;
        }
        bytes.addAll(chunk);
      }
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } on FormatException {
        response.statusCode = 400;
        response.write(jsonEncode(_error(null, -32700, 'Parse error')));
        return;
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['jsonrpc'] != '2.0' ||
          decoded['method'] is! String) {
        response.statusCode = 400;
        response.write(jsonEncode(_error(null, -32600, 'Invalid Request')));
        return;
      }
      final id = decoded['id'], method = decoded['method'] as String;
      if (id != null && id is! String && id is! int) {
        response.statusCode = 400;
        response.write(jsonEncode(_error(null, -32600, 'Invalid request id')));
        return;
      }
      if (id == null && method.startsWith('notifications/')) {
        response.statusCode = 202;
        return;
      }
      if (id == null) {
        response.statusCode = 202;
        return;
      }
      final protocol = request.headers.value('MCP-Protocol-Version');
      if (protocol != null &&
          !['2025-03-26', '2025-06-18', '2025-11-25'].contains(protocol)) {
        response.statusCode = 400;
        return;
      }
      final params = decoded['params'];
      if (params != null && params is! Map<String, dynamic>) {
        response.write(jsonEncode(_error(id, -32602, 'Invalid params')));
        return;
      }
      Object? result;
      switch (method) {
        case 'initialize':
          final requested = (params as Map?)?['protocolVersion'];
          result = {
            'protocolVersion':
                ['2025-03-26', '2025-06-18', '2025-11-25'].contains(requested)
                ? requested
                : '2025-11-25',
            'capabilities': {'tools': <String, Object?>{}},
            'serverInfo': {'name': 'Vex', 'version': '0.3.1'},
          };
        case 'ping':
          result = <String, Object?>{};
        case 'tools/list':
          result = {'tools': tools};
        case 'tools/call':
          final args = params as Map? ?? const {};
          final name = args['name'],
              arguments = args['arguments'] ?? <String, Object?>{};
          if (name is! String ||
              arguments is! Map<String, dynamic> ||
              !tools.any((t) => t['name'] == name)) {
            response.write(
              jsonEncode(
                _error(id, -32602, 'Unknown tool or invalid arguments'),
              ),
            );
            return;
          }
          try {
            validateMcpArguments(
              tools.firstWhere((tool) => tool['name'] == name),
              Map<String, Object?>.from(arguments),
            );
          } on ArgumentError catch (error) {
            response.write(
              jsonEncode(_error(id, -32602, error.message.toString())),
            );
            return;
          }
          try {
            final value = await dispatch(
              name,
              Map<String, Object?>.from(arguments),
            );
            result = {
              if (value is Map<String, Object?>) 'structuredContent': value,
              'content': [
                {'type': 'text', 'text': jsonEncode(value)},
              ],
            };
          } catch (error) {
            result = {
              'isError': true,
              'content': [
                {
                  'type': 'text',
                  'text': switch (error) {
                    StateError() => error.message,
                    ArgumentError() =>
                      error.message?.toString() ?? 'Invalid arguments',
                    _ => 'Operation failed; check Vex and the selected file permissions',
                  },
                },
              ],
            };
          }
        default:
          response.write(jsonEncode(_error(id, -32601, 'Method not found')));
          return;
      }
      response.write(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}),
      );
    } catch (_) {
      response.statusCode = 400;
    } finally {
      await response.close();
    }
  }

  Map<String, Object?> _error(Object? id, int code, String message) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  };
}
