import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/services/update_download_service.dart';
import 'package:vex/data/services/update_install_service.dart';
import 'package:vex/data/services/update_service.dart';

import 'support/update_fixture.dart';

class _Handshake implements UpdateHandshake {
  final events = <String>[];
  bool failReady = false;
  @override
  List<String> get arguments => ['/test-handshake'];
  @override
  Future<void> waitReady() async {
    events.add('ready');
    if (failReady) throw TimeoutException('not ready');
  }

  @override
  void approve() => events.add('approve');
  @override
  void cancel() => events.add('cancel');
  @override
  void close() => events.add('close');
}

void main() {
  late UpdateFixture fixture;
  setUp(() async => fixture = await UpdateFixture.create());
  tearDown(() async => fixture.close());

  for (final decision in [true, false]) {
    test('installer ready precedes save/close decision: $decision', () async {
      final handshake = _Handshake();
      final update = await fixture.download();
      final installer = SystemUpdateInstaller(
        handshake: () => handshake,
        launch: (path, args) async {
          expect(path, update.file.path);
          expect(args.first, '/test-handshake');
          handshake.events.add('launch');
        },
      );
      final result = await installer.install(
        update,
        closeWorkspace: (approve) async {
          handshake.events.add('save');
          if (decision) approve();
          return decision;
        },
      );
      expect(result, decision);
      expect(handshake.events, [
        'launch',
        'ready',
        'save',
        decision ? 'approve' : 'cancel',
        'close',
      ]);
    });
  }

  test('launch success alone never closes the app', () async {
    final handshake = _Handshake()..failReady = true;
    final update = await fixture.download();
    var closed = false;
    final installer = SystemUpdateInstaller(
      handshake: () => handshake,
      launch: (_, _) async {},
    );
    await expectLater(
      installer.install(
        update,
        closeWorkspace: (_) async {
          closed = true;
          return true;
        },
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(closed, isFalse);
    expect(handshake.events, ['ready', 'cancel', 'close']);
  });

  test('a changed verified file cannot launch any process', () async {
    final update = await fixture.download();
    await update.file.writeAsBytes([0]);
    final installer = SystemUpdateInstaller(
      launch: (_, _) async => fail('must not launch'),
    );
    await expectLater(
      installer.install(update),
      throwsA(isA<UpdateIntegrityException>()),
    );
  });

  test('Linux opens its package manager without closing Vex', () async {
    final linux = await UpdateFixture.create(target: UpdateTarget.linuxArm64);
    addTearDown(linux.close);
    final update = await linux.download();
    var opened = false;
    final installer = SystemUpdateInstaller(
      open: (path) async {
        expect(path, update.file.path);
        opened = true;
        return true;
      },
    );
    expect(
      await installer.install(
        update,
        closeWorkspace: (_) async => fail('must stay open'),
      ),
      isTrue,
    );
    expect(opened, isTrue);
  });

  test('real Windows named events acknowledge readiness and cancellation', () async {
    final handshake = WindowsUpdateHandshake(
      timeout: const Duration(seconds: 5),
    );
    addTearDown(handshake.close);
    final ready = handshake.arguments.first.split('=').last;
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "\$e=[Threading.EventWaitHandle]::OpenExisting('$ready'); \$e.Set(); \$e.Dispose()",
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    await handshake.waitReady();
    handshake.cancel();
    expect(handshake.approve, throwsA(isA<UpdateCancelled>()));
  }, skip: !Platform.isWindows);
}
