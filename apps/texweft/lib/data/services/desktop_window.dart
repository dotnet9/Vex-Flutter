import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Application and native integration tests share the same custom window chrome.
Future<void> initializeDesktopWindow({
  Size size = const Size(1392, 900),
}) async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: '笺纬 Texweft',
      size: size,
      minimumSize: const Size(900, 600),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    ),
    () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    },
  );
}
