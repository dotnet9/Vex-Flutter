import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:vex/data/services/update_download_service.dart';
import 'package:vex/data/services/update_service.dart';

class UpdateFixture {
  UpdateFixture._(this.server, this.directory, this.target);
  final HttpServer server;
  final Directory directory;
  final UpdateTarget target;
  final bytes = List<int>.generate(8192, (i) => i % 251);
  Future<void> Function(HttpRequest)? respond;
  String? checksumOverride;
  late final name = 'Vex-v9.0.0-${target.suffix}';
  String get checksum =>
      checksumOverride ?? '${sha256.convert(bytes)}  $name\n';
  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}/$path');
  UpdatePackage get package => UpdatePackage(
    target: target,
    installer: UpdateAsset(name: name, url: url(name), size: bytes.length),
    checksum: UpdateAsset(
      name: '$name.sha256',
      url: url('$name.sha256'),
      size: utf8.encode(checksum).length,
    ),
  );
  UpdateDownloader get downloader => UpdateDownloader(
    temporaryDirectory: () async => directory,
    allowLoopbackForTesting: true,
    inactivityTimeout: const Duration(seconds: 2),
  );

  static Future<UpdateFixture> create({
    UpdateTarget target = UpdateTarget.windowsX64,
  }) async {
    final fixture = UpdateFixture._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      await Directory.systemTemp.createTemp('vex-update-test-'),
      target,
    );
    fixture.server.listen((request) async {
      try {
        if (fixture.respond != null) {
          await fixture.respond!(request);
          return;
        }
        request.response.add(
          request.uri.path.endsWith('.sha256')
              ? utf8.encode(fixture.checksum)
              : fixture.bytes,
        );
        await request.response.close();
      } catch (_) {
        /* Cancellation deliberately closes the connection. */
      }
    });
    return fixture;
  }

  Future<VerifiedUpdate> download() =>
      downloader.download(package, cancellation: UpdateCancellation());
  Future<void> close() async {
    await server.close(force: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
