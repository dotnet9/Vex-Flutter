import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vex/app.dart';
import 'package:vex/data/services/file_service.dart';
import 'package:vex/ui/workspace/workspace_sidebar.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'folder scanning skips generated directories, reports progress and cancels',
    () async {
      final directory = await Directory.systemTemp.createTemp('vex-scan-');
      addTearDown(() async {
        expect(p.isWithin(Directory.systemTemp.path, directory.path), isTrue);
        await directory.delete(recursive: true);
      });
      final generated = await Directory(p.join(directory.path, 'build'))
          .create();
      await File(p.join(generated.path, 'generated.md'))
          .writeAsString('Generated');
      for (var i = 0; i < 260; i++) {
        await File(p.join(directory.path, '$i.md')).writeAsString('# Note');
      }
      final service = NativeDocumentFileService();
      var progress = 0;
      final scanned = await service.readFolder(
        directory.path,
        onProgress: (_) => progress++,
      );
      expect(scanned.files, hasLength(260));
      expect(scanned.directories, isEmpty);
      expect(progress, greaterThan(0));
      expect(
        (await service.readFolder(
          directory.path,
          excludedDirectories: {},
        )).files,
        hasLength(261),
      );
      var cancelled = false;
      final partial = await service.readFolder(
        directory.path,
        onProgress: (_) => cancelled = true,
        cancelled: () => cancelled,
      );
      expect(partial.files.length, lessThan(260));
    },
  );

  test('system document handles read and write original bytes with conflict checks', () async {
    var bytes = Uint8List.fromList(utf8.encode('# Original\r\n'));
    const path = 'vex-document:android:test';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeDocumentFileService.documents, (
          call,
        ) async {
          final args = call.arguments as Map;
          expect(args['location'], path);
          if (call.method == 'readDocument') {
            return {'bytes': bytes, 'name': 'Note.md'};
          }
          if (call.method == 'writeDocument') {
            bytes = args['bytes'] as Uint8List;
            return null;
          }
          throw MissingPluginException();
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeDocumentFileService.documents, null),
    );
    final service = NativeDocumentFileService();
    final opened = await service.read(path);
    expect(opened.name, 'Note.md');
    await service.write(
      path,
      '# New\n',
      expected: opened.text,
      format: opened.format,
    );
    expect(utf8.decode(bytes), '# New\r\n');
    await expectLater(
      service.write(path, 'Wrong', expected: opened.text),
      throwsA(isA<FileConflict>()),
    );
  });

  testWidgets('large directory trees build only visible rows', (tester) async {
    final vm = fakeWorkspace();
    final files = vm.files as MemoryFiles;
    for (var i = 0; i < 10000; i++) {
      files.content['/notes/$i.md'] = '# Note';
    }
    await vm.openFolder();
    await tester.pumpWidget(VexApp(viewModel: vm));
    await tester.pumpAndSettle();
    final sidebar = find.byType(WorkspaceSidebar);
    expect(
      find
          .descendant(of: sidebar, matching: find.byType(InkWell))
          .evaluate()
          .length,
      lessThan(100),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
