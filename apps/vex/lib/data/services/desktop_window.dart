import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Application and native integration tests share the same custom window chrome.
Future<void> initializeDesktopWindow({
  Size size = const Size(1392, 900),
  bool preventClose = true,
  bool nativeTitleBar = false,
}) async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: '维刻 Vex',
      size: size,
      minimumSize: const Size(900, 600),
      center: true,
      titleBarStyle: nativeTitleBar
          ? TitleBarStyle.normal
          : TitleBarStyle.hidden,
      windowButtonVisibility: nativeTitleBar,
    ),
    () async {
      await windowManager.setPreventClose(preventClose);
      await windowManager.show();
      await windowManager.focus();
    },
  );
}
