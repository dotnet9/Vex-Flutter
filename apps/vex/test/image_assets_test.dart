import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:vex/data/services/image_asset_service.dart';
import 'package:vex/domain/image_preferences.dart';
import 'package:vex/ui/workspace/workspace_view_model.dart';

import 'support/fakes.dart';

class _Picker extends ImageAssetService {
  final result = Completer<PickedImageAsset?>();
  @override
  Future<PickedImageAsset?> pick() => result.future;
}

void main() {
  final service = ImageAssetService();
  late Directory temporary;
  setUp(
    () async =>
        temporary = await Directory.systemTemp.createTemp('vex-images-'),
  );
  tearDown(() async => temporary.delete(recursive: true));

  test(
    'copies original bytes, encodes relative paths and never overwrites',
    () async {
      final source = File(p.join(temporary.path, 'source.png'));
      await source.writeAsBytes([1, 2, 3]);
      final document = p.join(temporary.path, 'note.md');
      final image = PickedImageAsset(
        '图 [1] (draft).png',
        await source.readAsBytes(),
        path: source.path,
      );
      final markdown = await service.markdown(
        image,
        documentPath: document,
        preferences: const ImagePreferences(folder: 'assets/images'),
      );
      expect(markdown, contains('assets/images/'));
      final html = md.markdownToHtml(markdown);
      expect(html, contains('<img'));
      expect(html, contains('alt="图 [1] (draft)"'));
      final copied = File(
        p.join(temporary.path, 'assets', 'images', image.name),
      );
      expect(await copied.readAsBytes(), [1, 2, 3]);
      expect(await source.readAsBytes(), [1, 2, 3]);
      expect(
        await service.markdown(
          image,
          documentPath: document,
          preferences: const ImagePreferences(folder: 'assets/images'),
        ),
        markdown,
      );
      final collision = await service.markdown(
        PickedImageAsset(image.name, Uint8List.fromList([4, 5, 6])),
        documentPath: document,
        preferences: const ImagePreferences(folder: 'assets/images'),
      );
      expect(collision, contains('-1.png'));
      expect(await copied.readAsBytes(), [1, 2, 3]);
    },
  );

  test('absolute links and disabling copying are independent', () async {
    final source = File(p.join(temporary.path, 'original.png'));
    await source.writeAsBytes([4]);
    final image = PickedImageAsset(
      'original.png',
      await source.readAsBytes(),
      path: source.path,
    );
    final markdown = await service.markdown(
      image,
      documentPath: p.join(temporary.path, 'note.md'),
      preferences: const ImagePreferences(copy: false, relative: false),
    );
    expect(markdown, contains(source.uri.toString()));
    expect(await Directory(p.join(temporary.path, 'assets')).exists(), isFalse);
    final relative = await service.markdown(
      image,
      documentPath: p.join(temporary.path, 'note.md'),
      preferences: const ImagePreferences(copy: false),
    );
    expect(relative, '![original](<original.png>)');
  });

  test(
    'untitled and system-provider documents embed portable image data',
    () async {
      for (final path in [null, 'content://documents/123']) {
        final markdown = await service.markdown(
          PickedImageAsset('photo.png', Uint8List.fromList([1, 2, 3])),
          documentPath: path,
          preferences: const ImagePreferences(),
        );
        expect(markdown, '![photo](<data:image/png;base64,AQID>)');
      }
    },
  );

  test('rejects invalid resource folders and unsupported inputs', () async {
    for (final folder in [
      '',
      '../outside',
      'a/../../outside',
      '/root',
      r'C:\temp',
      'a//b',
      'a/./b',
    ]) {
      expect(ImagePreferences.validFolder(folder), isFalse, reason: folder);
      expect(
        () => const ImagePreferences().copyWith(folder: folder),
        throwsFormatException,
      );
    }
    expect(ImagePreferences.validFolder('assets/images'), isTrue);
    await expectLater(
      service.markdown(
        PickedImageAsset('app.exe', Uint8List.fromList([1])),
        documentPath: null,
        preferences: const ImagePreferences(),
      ),
      throwsFormatException,
    );
  });

  test(
    'directory symlinks do not let image copies escape the document',
    () async {
      final notes = await Directory(p.join(temporary.path, 'notes')).create();
      final outside = await Directory(p.join(temporary.path, 'outside'))
          .create();
      final link = Link(p.join(notes.path, 'assets'));
      try {
        await link.create(outside.path);
      } on FileSystemException {
        return; // Some Windows hosts do not grant symbolic-link privileges.
      }
      await expectLater(
        service.markdown(
          PickedImageAsset('photo.png', Uint8List.fromList([1])),
          documentPath: p.join(notes.path, 'note.md'),
          preferences: const ImagePreferences(),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await outside.list().isEmpty, isTrue);
      await link.delete();
    },
  );

  test('insertion preserves selected position, is undoable and persists preferences', () async {
    final picker = _Picker(), settings = MemorySettings();
    final vm = WorkspaceViewModel(
      files: MemoryFiles(),
      settings: settings,
      recovery: MemoryRecovery(),
      imageAssets: picker,
    );
    vm.editor.session.replace('before after');
    vm.editor.select(7, 12);
    final insert = vm.insertImage();
    picker.result.complete(
      PickedImageAsset('photo.png', Uint8List.fromList([1])),
    );
    await insert;
    expect(vm.editor.text, 'before ![photo](<data:image/png;base64,AQ==>)');
    vm.editor.session.undo();
    expect(vm.editor.text, 'before after');
    vm.updateImagePreferences(copy: false, relative: false, folder: 'media');
    final restored = WorkspaceViewModel(
      files: MemoryFiles(),
      settings: settings,
      recovery: MemoryRecovery(),
    );
    await restored.initialize(watchFiles: false);
    expect(restored.imagePreferences.toJson(), vm.imagePreferences.toJson());
    restored.dispose();
    vm.dispose();
  });

  test(
    'cancel and edits during the picker do not replace newer document text',
    () async {
      for (final cancel in [true, false]) {
        final picker = _Picker();
        final vm = WorkspaceViewModel(
          files: MemoryFiles(),
          settings: MemorySettings(),
          recovery: MemoryRecovery(),
          imageAssets: picker,
        );
        final insert = vm.insertImage();
        vm.editor.session.replace('newer edit');
        picker.result.complete(
          cancel
              ? null
              : PickedImageAsset('photo.png', Uint8List.fromList([1])),
        );
        if (cancel) {
          await insert;
        } else {
          await expectLater(insert, throwsStateError);
        }
        expect(vm.editor.text, 'newer edit');
        vm.dispose();
      }
    },
  );
}
