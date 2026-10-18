import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'update_service.dart';

final class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

final class UpdateIntegrityException implements Exception {
  const UpdateIntegrityException();
}

final class UpdateCancellation {
  bool _cancelled = false;
  void Function()? _abort;
  bool get cancelled => _cancelled;
  void cancel() {
    _cancelled = true;
    _abort?.call();
  }

  void check() {
    if (_cancelled) throw const UpdateCancelled();
  }
}

final class UpdateProgress {
  const UpdateProgress(this.received, this.total);
  final int received, total;
  double get fraction => total == 0 ? 0 : (received / total).clamp(0, 1);
}

/// Only the downloader can create an installable package, after validation.
final class VerifiedUpdate {
  VerifiedUpdate._(this.package, this.file, this._digest, this._directory);
  final UpdatePackage package;
  final File file;
  final String _digest;
  final Directory _directory;

  Future<void> verify() async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() != package.installer.size ||
        (await sha256.bind(file.openRead()).first).toString() != _digest) {
      throw const UpdateIntegrityException();
    }
  }

  Future<void> discard() async {
    if (await _directory.exists()) await _directory.delete(recursive: true);
  }
}

class UpdateDownloader {
  UpdateDownloader({
    Future<Directory> Function()? temporaryDirectory,
    this.inactivityTimeout = const Duration(seconds: 30),
    this.deadline = const Duration(minutes: 15),
    this.allowLoopbackForTesting = false,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;
  final Duration inactivityTimeout, deadline;
  final bool allowLoopbackForTesting;

  Future<VerifiedUpdate> download(
    UpdatePackage package, {
    required UpdateCancellation cancellation,
    void Function(UpdateProgress)? onProgress,
  }) async {
    cancellation.check();
    final name = package.installer.name;
    if (!RegExp(r'^Vex-v\d+\.\d+\.\d+-[a-z0-9-]+\.(exe|dmg|deb|apk)$')
            .hasMatch(name) ||
        package.checksum.name != '$name.sha256' ||
        !name.endsWith('-${package.target.suffix}') ||
        package.installer.size < 1024 ||
        package.installer.size > 2 * 1024 * 1024 * 1024 ||
        package.checksum.size < 64 ||
        package.checksum.size > 4096) {
      throw const UpdateIntegrityException();
    }
    final temporary = await _temporaryDirectory();
    // Successful external handoffs keep their package until the next cleanup.
    // A long grace period avoids removing files a system installer still uses.
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await for (final entry in temporary.list(followLinks: false)) {
      if (entry is! Directory ||
          !RegExp(r'^vex-update-[A-Za-z0-9]+$')
              .hasMatch(p.basename(entry.path))) {
        continue;
      }
      try {
        if ((await entry.stat()).modified.isBefore(cutoff)) {
          await entry.delete(recursive: true);
        }
      } on FileSystemException {
        /* Another process may still own the installer. */
      }
    }
    cancellation.check();
    final directory = await temporary.createTemp('vex-update-');
    final client = HttpClient()
      ..connectionTimeout = inactivityTimeout
      ..autoUncompress = false;
    cancellation._abort = () => client.close(force: true);
    var expired = false;
    final timer = Timer(deadline, () {
      expired = true;
      client.close(force: true);
    });
    RandomAccessFile? output;
    try {
      cancellation.check();
      final checksumResponse = await _get(client, package.checksum.url);
      final checksumBytes = <int>[];
      await for (final chunk in checksumResponse.timeout(inactivityTimeout)) {
        cancellation.check();
        if (checksumBytes.length + chunk.length > 4096) {
          throw const UpdateIntegrityException();
        }
        checksumBytes.addAll(chunk);
      }
      if (checksumBytes.length != package.checksum.size) {
        throw const UpdateIntegrityException();
      }
      final checksumLine = utf8.decode(checksumBytes).trim();
      final checksumMatch = RegExp(r'^([a-fA-F0-9]{64}) [ *](.+)$')
          .firstMatch(checksumLine);
      if (checksumMatch == null || checksumMatch.group(2) != name) {
        throw const UpdateIntegrityException();
      }
      final expected = checksumMatch.group(1)!.toLowerCase();
      final response = await _get(client, package.installer.url);
      if (response.contentLength != -1 &&
          response.contentLength != package.installer.size) {
        throw const UpdateIntegrityException();
      }
      final part = File(p.join(directory.path, '$name.part'));
      output = await part.open(mode: FileMode.writeOnly);
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var received = 0;
      onProgress?.call(UpdateProgress(0, package.installer.size));
      await for (final chunk in response.timeout(inactivityTimeout)) {
        cancellation.check();
        received += chunk.length;
        if (received > package.installer.size) {
          throw const UpdateIntegrityException();
        }
        hasher.add(chunk);
        await output.writeFrom(chunk);
        onProgress?.call(UpdateProgress(received, package.installer.size));
      }
      hasher.close();
      if (received != package.installer.size ||
          digest.value.toString() != expected) {
        throw const UpdateIntegrityException();
      }
      await output.flush();
      await output.close();
      output = null;
      cancellation.check();
      if (expired) throw TimeoutException('Update download deadline exceeded');
      final file = await part.rename(p.join(directory.path, name));
      return VerifiedUpdate._(package, file, expected, directory);
    } catch (_) {
      await output?.close();
      await directory.delete(recursive: true);
      cancellation.check();
      if (expired) throw TimeoutException('Update download deadline exceeded');
      rethrow;
    } finally {
      timer.cancel();
      cancellation._abort = null;
      client.close(force: true);
    }
  }

  Future<HttpClientResponse> _get(HttpClient client, Uri uri) async {
    for (var redirects = 0; redirects <= 5; redirects++) {
      if (!_allowed(uri)) throw const FormatException('Untrusted update URL');
      final request = await client.getUrl(uri).timeout(inactivityTimeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Vex/Update');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final response = await request.close().timeout(inactivityTimeout);
      if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || redirects == 5) {
          throw const FormatException('Invalid update redirect');
        }
        uri = uri.resolve(location);
        // The connection is closed with the client; never buffer redirect bodies.
        unawaited(response.drain<void>().catchError((Object _) {}));
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateHttpException(response.statusCode);
      }
      if (response.headers.value(HttpHeaders.contentEncodingHeader) != null &&
          response.headers.value(HttpHeaders.contentEncodingHeader) !=
              'identity') {
        throw const UpdateIntegrityException();
      }
      return response;
    }
    throw const FormatException('Too many update redirects');
  }

  bool _allowed(Uri uri) {
    if (uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty) return false;
    if (allowLoopbackForTesting &&
        uri.scheme == 'http' &&
        const ['127.0.0.1', '::1'].contains(uri.host)) {
      return true;
    }
    return uri.scheme == 'https' &&
        uri.port == 443 &&
        const {
          'github.com',
          'release-assets.githubusercontent.com',
          'objects.githubusercontent.com',
          'github-releases.githubusercontent.com',
        }.contains(uri.host);
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
