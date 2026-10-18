import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import 'update_download_service.dart';
import 'update_service.dart';

typedef UpdateClose = Future<bool> Function(void Function() approveInstaller);

final class UpdateInstallPermissionRequired implements Exception {
  const UpdateInstallPermissionRequired();
}

abstract interface class UpdateInstaller {
  Future<bool> install(VerifiedUpdate update, {UpdateClose? closeWorkspace});
}

abstract interface class UpdateHandshake {
  List<String> get arguments;
  Future<void> waitReady();
  void approve();
  void cancel();
  void close();
}

class SystemUpdateInstaller implements UpdateInstaller {
  SystemUpdateInstaller({
    Future<void> Function(String, List<String>)? launch,
    Future<bool> Function(String)? open,
    UpdateHandshake Function()? handshake,
  }) : _launch = launch ?? _start,
       _open = open ?? _openFile,
       _handshake = handshake ?? WindowsUpdateHandshake.new;
  final Future<void> Function(String, List<String>) _launch;
  final Future<bool> Function(String) _open;
  final UpdateHandshake Function() _handshake;
  static const _android = MethodChannel('vex/updates');

  static Future<void> _start(String path, List<String> arguments) async {
    await Process.start(path, arguments, mode: ProcessStartMode.detached);
  }

  static Future<bool> _openFile(String path) async =>
      (await OpenFilex.open(path)).type == ResultType.done;

  @override
  Future<bool> install(
    VerifiedUpdate update, {
    UpdateClose? closeWorkspace,
  }) async {
    await update.verify();
    if (update.package.target == UpdateTarget.windowsX64) {
      if (closeWorkspace == null) throw StateError('Safe close is unavailable');
      final handshake = _handshake();
      var approved = false;
      try {
        await _launch(update.file.path, [
          ...handshake.arguments,
          '/LOG=${update.file.path}.install.log',
        ]);
        await handshake.waitReady();
        final closed = await closeWorkspace(() {
          handshake.approve();
          approved = true;
        });
        return closed && approved;
      } finally {
        if (!approved) handshake.cancel();
        handshake.close();
      }
    }
    if (const [
      UpdateTarget.androidArm,
      UpdateTarget.androidArm64,
      UpdateTarget.androidX64,
    ].contains(update.package.target)) {
      if (await _android.invokeMethod<bool>('canInstallPackages') != true) {
        await _android.invokeMethod<void>('installPermissionSettings');
        throw const UpdateInstallPermissionRequired();
      }
    }
    if (!await _open(update.file.path)) {
      throw StateError('Cannot open system installer');
    }
    return true;
  }
}

/// The setup must acknowledge readiness, then wait for approval or cancellation.
/// Polls are non-blocking so save prompts and the Flutter UI stay responsive.
final class WindowsUpdateHandshake implements UpdateHandshake {
  WindowsUpdateHandshake({this.timeout = const Duration(seconds: 60)}) {
    if (!Platform.isWindows) throw UnsupportedError('Windows only');
    final random = Random.secure();
    _name =
        'Local\\Vex.Update.${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    try {
      for (final suffix in ['Ready', 'Proceed', 'Cancel']) {
        final name = '$_name.$suffix'.toNativeUtf16();
        try {
          final event = _create(nullptr, 1, 0, name);
          if (event == nullptr) {
            throw const OSError('Cannot create update event');
          }
          _handles.add(event);
        } finally {
          calloc.free(name);
        }
      }
    } catch (_) {
      close();
      rethrow;
    }
  }
  final Duration timeout;
  late final String _name;
  final _handles = <Pointer<Void>>[];
  static final _kernel = DynamicLibrary.open('kernel32.dll');
  static final _create = _kernel
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Int32, Int32, Pointer<Utf16>),
        Pointer<Void> Function(Pointer<Void>, int, int, Pointer<Utf16>)
      >('CreateEventW');
  static final _wait = _kernel
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int)
      >('WaitForSingleObject');
  static final _set = _kernel
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('SetEvent');
  static final _close = _kernel
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('CloseHandle');

  @override
  List<String> get arguments => [
    '/VEXUPDATEREADY=$_name.Ready',
    '/VEXUPDATEPROCEED=$_name.Proceed',
    '/VEXUPDATECANCEL=$_name.Cancel',
  ];
  @override
  Future<void> waitReady() async {
    final watch = Stopwatch()..start();
    while (watch.elapsed < timeout && _handles.length == 3) {
      if (_wait(_handles[2], 0) == 0) throw const UpdateCancelled();
      final status = _wait(_handles[0], 0);
      if (status == 0) return;
      if (status != 258) throw const OSError('Cannot wait for installer');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('Installer did not become ready', timeout);
  }

  @override
  void approve() {
    if (_handles.length == 3 && _wait(_handles[2], 0) == 0) {
      throw const UpdateCancelled();
    }
    if (_handles.length != 3 || _set(_handles[1]) == 0) {
      throw const OSError('Cannot approve installer');
    }
  }

  @override
  void cancel() {
    if (_handles.length == 3) _set(_handles[2]);
  }

  @override
  void close() {
    for (final handle in _handles) {
      _close(handle);
    }
    _handles.clear();
  }
}
