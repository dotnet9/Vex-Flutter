import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:typed_data';

import 'package:pub_semver/pub_semver.dart';

enum UpdateStatus { noRelease, current, available, localNewer, unknownCurrent }

final class UpdateCheckResult {
  const UpdateCheckResult(this.status, {this.tag, this.assets = const []});
  final UpdateStatus status;
  final String? tag;
  final List<UpdateAsset> assets;

  UpdatePackage? packageFor(UpdateTarget? target) {
    if (target == null || tag == null) return null;
    final version = _version(tag!);
    if (version == null) return null;
    final name = 'Vex-v$version-${target.suffix}';
    final installers = assets.where((asset) => asset.name == name).toList();
    final checksums = assets
        .where((asset) => asset.name == '$name.sha256')
        .toList();
    if (installers.length != 1 || checksums.length != 1) return null;
    final installer = installers.single, checksum = checksums.single;
    if (installer.size < 1024 ||
        installer.size > 2 * 1024 * 1024 * 1024 ||
        checksum.size < 64 ||
        checksum.size > 4096) {
      return null;
    }
    for (final asset in [installer, checksum]) {
      final expected = Uri.https(
        'github.com',
        '/dotnet9/Vex-Flutter/releases/download/$tag/${asset.name}',
      );
      if (asset.url != expected) return null;
    }
    return UpdatePackage(
      target: target,
      installer: installer,
      checksum: checksum,
    );
  }

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

enum UpdateTarget {
  windowsX64('windows-x64-setup.exe'),
  macos('macos-universal.dmg'),
  linuxX64('linux-x64.deb'),
  linuxArm64('linux-arm64.deb'),
  androidArm('android-armv7.apk'),
  androidArm64('android-arm64.apk'),
  androidX64('android-x64.apk');

  const UpdateTarget(this.suffix);
  final String suffix;
  static UpdateTarget? current() => switch (Abi.current()) {
    Abi.windowsX64 => windowsX64,
    Abi.macosX64 || Abi.macosArm64 => macos,
    Abi.linuxX64 => linuxX64,
    Abi.linuxArm64 => linuxArm64,
    Abi.androidArm => androidArm,
    Abi.androidArm64 => androidArm64,
    Abi.androidX64 => androidX64,
    _ => null,
  };
}

final class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.url,
    required this.size,
  });
  final String name;
  final Uri url;
  final int size;
}

final class UpdatePackage {
  const UpdatePackage({
    required this.target,
    required this.installer,
    required this.checksum,
  });
  final UpdateTarget target;
  final UpdateAsset installer, checksum;
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
    final result = UpdateCheckResult.compare(
      version,
      data['tag_name'] as String,
    );
    final assets = <UpdateAsset>[];
    if (data['assets'] is List) {
      for (final asset in data['assets'] as List) {
        if (asset is! Map ||
            asset['state'] != 'uploaded' ||
            asset['name'] is! String ||
            asset['size'] is! int ||
            asset['browser_download_url'] is! String) {
          continue;
        }
        final url = Uri.tryParse(asset['browser_download_url'] as String);
        if (url != null) {
          assets.add(
            UpdateAsset(
              name: asset['name'] as String,
              url: url,
              size: asset['size'] as int,
            ),
          );
        }
      }
    }
    return UpdateCheckResult(
      result.status,
      tag: result.tag,
      assets: List.unmodifiable(assets),
    );
  }

  @override
  void close() {
    _closed = true;
    _active?.close(force: true);
  }
}
