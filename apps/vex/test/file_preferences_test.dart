import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vex/data/services/document_codec.dart';
import 'package:vex/data/services/file_service.dart';
import 'package:vex/domain/file_preferences.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

void main() {
  test(
    'UTF-8 BOM and newline format roundtrip without changing editor text',
    () async {
      const text = '# 中文\n\n正文\n';
      for (final encoding in [
        DocumentEncoding.utf8,
        DocumentEncoding.utf8Bom,
      ]) {
        for (final newline in [DocumentNewline.lf, DocumentNewline.crlf]) {
          final bytes = await encodeDocument(
            text,
            TextFileFormat(encoding: encoding, newline: newline),
          );
          expect(
            bytes.take(3).toList(),
            encoding == DocumentEncoding.utf8Bom
                ? [239, 187, 191]
                : utf8.encode('# 中').take(3).toList(),
          );
          final result = await decodeDocument(bytes);
          expect(result.text, text);
          expect(result.format.encoding, encoding);
          expect(result.format.newline, newline);
        }
      }
    },
  );

  test(
    'native save preserves BOM/CRLF and refuses deleted external file',
    () async {
      final dir = await Directory.systemTemp.createTemp('vex-encoding-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/note.md';
      const format = TextFileFormat(
        encoding: DocumentEncoding.utf8Bom,
        newline: DocumentNewline.crlf,
      );
      await File(path).writeAsBytes(await encodeDocument('第一行\n第二行', format));
      final files = NativeDocumentFileService();
      final opened = await files.read(path);
      expect(opened.text, '第一行\n第二行');
      await files.write(
        path,
        '更新\n正文',
        expected: opened.text,
        format: opened.format,
      );
      expect(await File(path).readAsBytes(), [
        239,
        187,
        191,
        ...utf8.encode('更新\r\n正文'),
      ]);
      await File(path).delete();
      await expectLater(
        files.write(path, 'new', expected: '更新\n正文'),
        throwsA(isA<FileConflict>()),
      );
      expect(await File(path).exists(), isFalse);
    },
  );

  testWidgets('autosave defaults off; recovery does not write original file', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content['/a.md'] = 'old';
    await vm.openPath('/a.md');
    vm.editor.session.replace('new');
    await tester.pump(const Duration(seconds: 12));
    expect(files.content['/a.md'], 'old');
    expect(vm.filePreferences.autoSave, isFalse);
    await vm.flushRecovery();
    expect((vm.recovery as MemoryRecovery).value.single['text'], 'new');
  });

  testWidgets('debounced autosave saves each document even after switching', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content.addAll({'/a.md': 'a', '/b.md': 'b'});
    await vm.updateFilePreferences(autoSave: true, recovery: false);
    await vm.openPath('/a.md');
    final a = vm.current;
    vm.editor.session.replace('a1');
    await tester.pump(const Duration(seconds: 1));
    vm.editor.session.replace('a2');
    await vm.openPath('/b.md');
    vm.editor.session.replace('b2');
    await tester.pump(const Duration(seconds: 1));
    expect(files.content['/a.md'], 'a');
    await tester.pump(const Duration(seconds: 1));
    await vm.finishPendingSaves();
    expect(files.content['/a.md'], 'a2');
    expect(files.content['/b.md'], 'b2');
    expect(a.editor.session.isDirty, isFalse);
    expect(vm.editor.session.isDirty, isFalse);
    expect((vm.recovery as MemoryRecovery).value, isEmpty);
  });

  testWidgets('autosave never opens a save picker for unnamed documents', (
    tester,
  ) async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    await vm.updateFilePreferences(autoSave: true);
    vm.editor.session.replace('draft');
    await tester.pump(const Duration(seconds: 10));
    expect((vm.files as MemoryFiles).content, isEmpty);
    expect(vm.editor.session.isDirty, isTrue);
    await vm.updateFilePreferences(recovery: false);
    expect((vm.recovery as MemoryRecovery).value, isEmpty);
  });

  testWidgets(
    'autosave conflict retains local edits and original external file',
    (tester) async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content['/a.md'] = 'old';
      await vm.openPath('/a.md');
      await vm.updateFilePreferences(autoSave: true);
      vm.editor.session.replace('local');
      files.content['/a.md'] = 'external';
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(files.content['/a.md'], 'external');
      expect(vm.editor.text, 'local');
      expect(vm.editor.session.isDirty, isTrue);
      expect(vm.status, vm.strings.fileConflict);
    },
  );

  test('queued saves keep the latest snapshot and baseline in order', () async {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final files = vm.files as MemoryFiles;
    files.content['/a.md'] = 'old';
    await vm.openPath('/a.md');
    final barrier = Completer<void>();
    files.beforeWrite = () => barrier.future;
    vm.editor.session.replace('first');
    final first = vm.save();
    await Future<void>.delayed(Duration.zero);
    vm.editor.session.replace('second');
    final second = vm.save();
    barrier.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(files.content['/a.md'], 'second');
    expect(vm.current.persistedText, 'second');
    expect(vm.editor.session.isDirty, isFalse);
  });

  test(
    'manual save writes committed text without clearing an IME candidate',
    () async {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final files = vm.files as MemoryFiles;
      files.content['/a.md'] = 'old';
      await vm.openPath('/a.md');
      vm.editor.session.replace('accepted');
      final candidate = const TextEditingValue(
        text: 'accepted ni',
        selection: TextSelection.collapsed(offset: 11),
        composing: TextRange(start: 9, end: 11),
      );
      vm.editor.source.value = candidate;

      expect(await vm.save(), isTrue);

      expect(files.content['/a.md'], 'accepted');
      expect(vm.editor.source.value, candidate);
      expect(vm.editor.session.isDirty, isFalse);
      vm.editor.source.value = const TextEditingValue(
        text: 'accepted 你',
        selection: TextSelection.collapsed(offset: 10),
      );
      expect(vm.editor.session.isDirty, isTrue);
      vm.editor.session.undo();
      expect(vm.editor.session.text, 'accepted');
      expect(vm.editor.session.isDirty, isFalse);
    },
  );

  test(
    'startup restoration and defaults are persisted independently of recovery',
    () async {
      final vm = fakeWorkspace();
      final files = vm.files as MemoryFiles;
      files.content.addAll({'/a.md': 'a', '/b.md': 'b'});
      await vm.openPath('/a.md');
      await vm.openPath('/b.md');
      await vm.openFolder();
      await vm.updateFilePreferences(
        restoreWorkspace: true,
        recovery: false,
        encoding: DocumentEncoding.utf8Bom,
        newline: DocumentNewline.crlf,
      );
      final restored = WorkspaceViewModel(
        files: files,
        settings: vm.settings,
        recovery: vm.recovery,
      );
      addTearDown(restored.dispose);
      await restored.initialize(watchFiles: false);
      expect(restored.documents.map((d) => d.path), ['/a.md', '/b.md']);
      expect(restored.current.path, '/b.md');
      expect(restored.folder?.path, '/notes');
      expect(restored.recoverable, isEmpty);
      restored.newDocument();
      expect(restored.current.format.encoding, DocumentEncoding.utf8Bom);
      expect(restored.current.format.newline, DocumentNewline.crlf);
      vm.dispose();
    },
  );

  test(
    'invalid UTF-8 with a BOM fails instead of silently replacing bytes',
    () async {
      await expectLater(
        decodeDocument(Uint8List.fromList([239, 187, 191, 255])),
        throwsFormatException,
      );
    },
  );
}
