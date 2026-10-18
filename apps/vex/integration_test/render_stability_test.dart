import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:vex/data/services/desktop_window.dart';

import '../test/support/render_stability_checks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native scrolling and chapter arrival frame stability', (
    tester,
  ) async {
    await initializeDesktopWindow();
    final boundary = GlobalKey();
    final folder = Platform.environment['VEX_CAPTURE_DIR'];
    final frames = <String, Uint8List>{};
    if (folder != null) await Directory(folder).create(recursive: true);
    await checkDocumentFrameStability(
      tester,
      boundary: boundary,
      capture: (name) async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final pixels = data!.buffer.asUint8List();
          final viewport = tester.getRect(find.byType(SuperListView));
          final text = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().startsWith('Local text'),
          );
          final paragraph = text
              .evaluate()
              .map((element) {
                final box = element.renderObject! as RenderBox;
                return box.localToGlobal(Offset.zero) & box.size;
              })
              .firstWhere((rect) => viewport.contains(rect.center))
              .intersect(viewport);
          final background =
              (viewport.top.toInt() * image.width + viewport.left.toInt() + 1) *
              4;
          var ink = 0;
          for (
            var y = paragraph.top.ceil();
            y < paragraph.bottom.floor();
            y++
          ) {
            for (
              var x = paragraph.left.ceil();
              x < paragraph.right.floor();
              x++
            ) {
              final offset = (y * image.width + x) * 4;
              var contrast = 0;
              for (var c = 0; c < 3; c++) {
                contrast += (pixels[offset + c] - pixels[background + c]).abs();
              }
              if (contrast > 60) ink++;
            }
          }
          expect(
            ink,
            greaterThan(50),
            reason: '$name paragraph must actually paint.',
          );
          final content = BytesBuilder(copy: false);
          for (var y = viewport.top.ceil(); y < viewport.bottom.floor(); y++) {
            final start = (y * image.width + viewport.left.ceil()) * 4;
            final end = (y * image.width + viewport.right.floor() - 16) * 4;
            content.add(pixels.sublist(start, end));
          }
          if (name.endsWith('-arrived')) {
            frames[name] = content.takeBytes();
          } else {
            expect(
              listEquals(
                frames.remove(name.replaceFirst('-settled', '-arrived')),
                content.takeBytes(),
              ),
              isTrue,
              reason: '$name document pixels must not change after arrival.',
            );
          }
          if (folder != null) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File('$folder/$name.png')
                .writeAsBytes(png!.buffer.asUint8List());
          }
        } finally {
          image.dispose();
        }
      },
    );
  });
}
