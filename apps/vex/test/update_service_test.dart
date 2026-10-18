import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/services/update_service.dart';

void main() {
  for (final item in [
    ('0.3.1', 'v0.3.1', UpdateStatus.current),
    ('0.3.1+99', 'v0.3.1+100', UpdateStatus.current),
    ('0.3.9', 'v0.3.10', UpdateStatus.available),
    ('0.3.1-beta.2', 'v0.3.1', UpdateStatus.available),
    ('0.4.0', 'v0.3.10', UpdateStatus.localNewer),
    ('dev', 'v0.3.1', UpdateStatus.unknownCurrent),
    (null, 'v0.3.1', UpdateStatus.unknownCurrent),
  ]) {
    test('compares ${item.$1} with ${item.$2} semantically', () {
      final result = UpdateCheckResult.compare(item.$1, item.$2);
      expect(result.status, item.$3);
      expect(result.releasePage.host, 'github.com');
      expect(
        result.releasePage.path,
        '/dotnet9/Vex-Flutter/releases/tag/${item.$2}',
      );
    });
  }

  for (final tag in ['dev', 'v0.4.0-beta', 'https://example.com', 'null']) {
    test('rejects an invalid or preview stable tag: $tag', () {
      expect(
        () => UpdateCheckResult.compare('0.3.1', tag),
        throwsFormatException,
      );
    });
  }

  group('release HTTP response', () {
    late HttpServer server;
    late GitHubUpdateChecker checker;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      checker = GitHubUpdateChecker(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/latest'),
        timeout: const Duration(seconds: 2),
      );
    });
    tearDown(() async {
      checker.close();
      await server.close(force: true);
    });

    test('checks a stable release with identifiable API headers', () async {
      server.listen((request) {
        expect(request.headers.value('User-Agent'), 'Vex/0.3.1');
        expect(request.headers.value('Accept'), 'application/vnd.github+json');
        request.response.write(
          jsonEncode({
            'tag_name': 'v0.3.2',
            'draft': false,
            'prerelease': false,
            'html_url': 'https://untrusted.example.com',
          }),
        );
        unawaited(request.response.close());
      });
      final result = await checker.check('0.3.1');
      expect(result.status, UpdateStatus.available);
      expect(
        result.releasePage.toString(),
        'https://github.com/dotnet9/Vex-Flutter/releases/tag/v0.3.2',
      );
    });

    test('404 means no stable release, not latest installed', () async {
      server.listen((request) {
        request.response.statusCode = HttpStatus.notFound;
        unawaited(request.response.close());
      });
      expect((await checker.check('0.3.1')).status, UpdateStatus.noRelease);
    });

    test('rate limiting is an error and the same checker can retry', () async {
      var attempt = 0;
      server.listen((request) {
        if (attempt++ == 0) {
          request.response.statusCode = HttpStatus.forbidden;
        } else {
          request.response.write(
            '{"tag_name":"v0.3.1","draft":false,"prerelease":false}',
          );
        }
        unawaited(request.response.close());
      });
      await expectLater(
        checker.check('0.3.1'),
        throwsA(
          isA<UpdateHttpException>().having(
            (error) => error.statusCode,
            'status',
            HttpStatus.forbidden,
          ),
        ),
      );
      expect((await checker.check('0.3.1')).status, UpdateStatus.current);
    });

    test('rejects incomplete and draft responses', () async {
      var attempt = 0;
      server.listen((request) {
        request.response.write(
          attempt++ == 0
              ? '{"tag_name":"v0.3.2"}'
              : '{"tag_name":"v0.3.2","draft":true,"prerelease":false}',
        );
        unawaited(request.response.close());
      });
      await expectLater(checker.check('0.3.1'), throwsFormatException);
      await expectLater(checker.check('0.3.1'), throwsFormatException);
    });

    test('rejects oversized response bodies', () async {
      server.listen((request) {
        request.response.write('x' * (1024 * 1024 + 1));
        unawaited(request.response.close().catchError((Object _) {}));
      });
      await expectLater(checker.check('0.3.1'), throwsFormatException);
    });

    test('deadline covers a response stalled after its headers', () async {
      checker.close();
      checker = GitHubUpdateChecker(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/latest'),
        timeout: const Duration(milliseconds: 150),
      );
      server.listen((request) {
        request.response.write('{');
        unawaited(request.response.flush().catchError((Object _) {}));
      });
      await expectLater(
        checker.check('0.3.1'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
      'closing cancels an active request and prevents later checks',
      () async {
        final received = Completer<void>();
        server.listen((request) => received.complete());
        final pending = checker.check('0.3.1');
        final expectation = expectLater(pending, throwsA(isA<HttpException>()));
        await received.future;
        checker.close();
        await expectation;
        await expectLater(checker.check('0.3.1'), throwsStateError);
      },
    );
  });
}
