import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pub_semver/pub_semver.dart';

enum UpdateStatus { noRelease, current, available, localNewer, unknownCurrent }

final class UpdateCheckResult {
  const UpdateCheckResult(this.status, {this.tag});
  final UpdateStatus status;
  final String? tag;
  static final releases = Uri.https(
    'github.com',
    '/dotnet9/Vex-Flutter/releases',
  );
  Uri get releasePage => tag == null
      ? releases
      : Uri.https('github.com', '/dotnet9/Vex-Flutter/releases/tag/$tag');

  factory UpdateCheckResult.compare(String? current, String tag) {
    final latest = _version(tag);
    if (latest == null || latest.isPreRelease) {
      throw const FormatException('Invalid stable release version');
    }
    final local = current == null ? null : _version(current);
    final comparison = local?.compareTo(latest);
    return UpdateCheckResult(
      comparison == null
          ? UpdateStatus.unknownCurrent
          : comparison == 0
          ? UpdateStatus.current
          : comparison < 0
          ? UpdateStatus.available
          : UpdateStatus.localNewer,
      tag: tag,
    );
  }

  static Version? _version(String text) {
    try {
      // Build numbers identify packages, not newer user-facing releases.
      final version = Version.parse(text.replaceFirst(RegExp(r'^v'), ''));
      return Version(
        version.major,
        version.minor,
        version.patch,
        pre: version.preRelease.isEmpty ? null : version.preRelease.join('.'),
      );
    } on FormatException {
      return null;
    }
  }
}

final class UpdateHttpException implements Exception {
  const UpdateHttpException(this.statusCode);
  final int statusCode;
}

abstract interface class UpdateChecker {
  Future<UpdateCheckResult> check(String? currentVersion);
  void close();
}

final class GitHubUpdateChecker implements UpdateChecker {
  GitHubUpdateChecker({
    Uri? endpoint,
    this.timeout = const Duration(seconds: 25),
  }) : endpoint =
           endpoint ??
           Uri.https(
             'api.github.com',
             '/repos/dotnet9/Vex-Flutter/releases/latest',
           );
  final Uri endpoint;
  final Duration timeout;
  HttpClient? _active;
  bool _closed = false;

  @override
  Future<UpdateCheckResult> check(String? currentVersion) async {
    if (_closed || _active != null) {
      throw StateError('Update checker is closed or already checking');
    }
    final client = HttpClient()..connectionTimeout = timeout;
    _active = client;
    try {
      // The deadline includes DNS, headers and a response body that may stall.
      return await _fetch(client, currentVersion).timeout(timeout);
    } finally {
      client.close(force: true);
      _active = null;
    }
  }

  Future<UpdateCheckResult> _fetch(HttpClient client, String? version) async {
    final request = await client.getUrl(endpoint);
    request.headers.set(HttpHeaders.userAgentHeader, 'Vex/${version ?? 'dev'}');
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    final response = await request.close();
    if (response.statusCode == HttpStatus.notFound) {
      return const UpdateCheckResult(UpdateStatus.noRelease);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateHttpException(response.statusCode);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw const FormatException('Release response exceeds size limit');
      }
      bytes.add(chunk);
    }
    final data = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (data is! Map ||
        data['draft'] != false ||
        data['prerelease'] != false ||
        data['tag_name'] is! String) {
      throw const FormatException('Invalid stable release metadata');
    }
    return UpdateCheckResult.compare(version, data['tag_name'] as String);
  }

  @override
  void close() {
    _closed = true;
    _active?.close(force: true);
  }
}
