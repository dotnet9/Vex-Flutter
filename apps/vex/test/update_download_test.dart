import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/services/update_download_service.dart';
import 'package:vex/data/services/update_service.dart';

import 'support/update_fixture.dart';

void main() {
  late UpdateFixture fixture;
  setUp(() async => fixture = await UpdateFixture.create());
  tearDown(() async => fixture.close());

  test(
    'streams, reports progress and exposes only a verified completed file',
    () async {
      final progress = <UpdateProgress>[];
      final result = await fixture.downloader.download(
        fixture.package,
        cancellation: UpdateCancellation(),
        onProgress: progress.add,
      );
      expect(await result.file.readAsBytes(), fixture.bytes);
      expect(progress.first.fraction, 0);
      expect(progress.last.fraction, 1);
      expect(await File('${result.file.path}.part').exists(), isFalse);
      await result.verify();
      await result.discard();
      expect(await fixture.directory.list().toList(), isEmpty);
    },
  );

  test(
    'rejects checksum mismatch and a checksum for a different file',
    () async {
      for (final line in [
        '${'0' * 64}  ${fixture.name}\n',
        '${'0' * 64}  other.exe\n',
      ]) {
        fixture.checksumOverride = line;
        await expectLater(
          fixture.download(),
          throwsA(isA<UpdateIntegrityException>()),
        );
        expect(await fixture.directory.list().toList(), isEmpty);
      }
      fixture.checksumOverride = null;
      await (await fixture.download()).discard();
    },
  );

  for (final size in [1024, 16384]) {
    test('rejects truncated or oversized chunked body: $size', () async {
      fixture.respond = (request) async {
        request.response.add(
          request.uri.path.endsWith('.sha256')
              ? utf8.encode(fixture.checksum)
              : List<int>.filled(size, 0),
        );
        await request.response.close();
      };
      await expectLater(
        fixture.download(),
        throwsA(isA<UpdateIntegrityException>()),
      );
      expect(await fixture.directory.list().toList(), isEmpty);
    });
  }

  test(
    'cancellation removes partial data and a retry starts cleanly',
    () async {
      final cancel = UpdateCancellation();
      await expectLater(
        fixture.downloader.download(
          fixture.package,
          cancellation: cancel,
          onProgress: (progress) {
            if (progress.received > 0) cancel.cancel();
          },
        ),
        throwsA(isA<UpdateCancelled>()),
      );
      expect(await fixture.directory.list().toList(), isEmpty);
      await (await fixture.download()).discard();
    },
  );

  for (final redirect in [
    'http://example.com/unsafe',
    'https://untrusted.example.com/installer',
    '/loop',
  ]) {
    test('rejects untrusted redirects or a redirect loop: $redirect', () async {
      fixture.respond = (request) async {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, redirect);
        await request.response.close();
      };
      await expectLater(fixture.download(), throwsFormatException);
      expect(await fixture.directory.list().toList(), isEmpty);
    });
  }

  test('response stall times out, with all partial files removed', () async {
    fixture.respond = (request) async {
      request.response.add([65]);
      await request.response.flush();
    };
    final downloader = UpdateDownloader(
      temporaryDirectory: () async => fixture.directory,
      allowLoopbackForTesting: true,
      inactivityTimeout: const Duration(milliseconds: 100),
    );
    await expectLater(
      downloader.download(fixture.package, cancellation: UpdateCancellation()),
      throwsA(isA<TimeoutException>()),
    );
    expect(await fixture.directory.list().toList(), isEmpty);
  });

  test(
    'production downloader refuses insecure URLs and forged local paths',
    () async {
      await expectLater(
        UpdateDownloader(temporaryDirectory: () async => fixture.directory)
            .download(fixture.package, cancellation: UpdateCancellation()),
        throwsFormatException,
      );
      final invalid = UpdatePackage(
        target: fixture.target,
        installer: UpdateAsset(
          name: '../vex.exe',
          url: fixture.url('installer'),
          size: 8192,
        ),
        checksum: fixture.package.checksum,
      );
      await expectLater(
        fixture.downloader.download(
          invalid,
          cancellation: UpdateCancellation(),
        ),
        throwsA(isA<UpdateIntegrityException>()),
      );
      expect(await fixture.directory.list().toList(), isEmpty);
    },
  );

  test('re-verification rejects a modified installer before launch', () async {
    final result = await fixture.download();
    await result.file.writeAsBytes(List<int>.filled(fixture.bytes.length, 0));
    await expectLater(
      result.verify(),
      throwsA(isA<UpdateIntegrityException>()),
    );
  });
}
