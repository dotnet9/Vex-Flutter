import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vex/data/services/social_copy_service.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native clipboard carries rich HTML and plain text', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final previous = await Clipboard.getData(Clipboard.kTextPlain);
    try {
      final content = await SocialCopyService().prepare(
        platform: PublishingPlatform.wechat,
        source: '# 维刻\n\n## 想法\n\n**中文** & English 🌱\n',
        title: '剪贴板验证',
        typography: MarkdownTypography.technical,
      );
      await SocialCopyService.write(content);
      expect(
        (await Clipboard.getData(Clipboard.kTextPlain))?.text,
        content.text,
      );
      if (Platform.isWindows) {
        final result = await Process.run('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class NativeClipboard {
  [DllImport("user32.dll")] public static extern bool OpenClipboard(IntPtr owner);
  [DllImport("user32.dll")] public static extern bool CloseClipboard();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern uint RegisterClipboardFormat(string name);
  [DllImport("user32.dll")] public static extern IntPtr GetClipboardData(uint format);
  [DllImport("kernel32.dll")] public static extern IntPtr GlobalLock(IntPtr memory);
  [DllImport("kernel32.dll")] public static extern bool GlobalUnlock(IntPtr memory);
  [DllImport("kernel32.dll")] public static extern UIntPtr GlobalSize(IntPtr memory);
}
'@
if (-not [NativeClipboard]::OpenClipboard([IntPtr]::Zero)) { throw 'Clipboard busy' }
try {
  $handle = [NativeClipboard]::GetClipboardData([NativeClipboard]::RegisterClipboardFormat('HTML Format'))
  if ($handle -eq [IntPtr]::Zero) { throw 'HTML clipboard format missing' }
  $pointer = [NativeClipboard]::GlobalLock($handle)
  try {
    $bytes = New-Object byte[] ([int][NativeClipboard]::GlobalSize($handle).ToUInt64())
    [Runtime.InteropServices.Marshal]::Copy($pointer, $bytes, 0, $bytes.Length)
    [Convert]::ToBase64String($bytes)
  } finally { [void][NativeClipboard]::GlobalUnlock($handle) }
} finally { [void][NativeClipboard]::CloseClipboard() }
''',
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        final bytes = base64Decode((result.stdout as String).trim());
        final header = utf8.decode(bytes);
        int offset(String name) =>
            int.parse(RegExp('$name:(\\d+)').firstMatch(header)!.group(1)!);
        final fragment = utf8.decode(
          bytes.sublist(offset('StartFragment'), offset('EndFragment')),
        );
        expect(fragment, content.html);
        expect(fragment, contains('<strong'));
        expect(fragment, contains('border-left:3px'));
        expect(fragment, contains('🌱'));
      }
    } finally {
      await Clipboard.setData(previous ?? const ClipboardData(text: ''));
    }
  });
}
