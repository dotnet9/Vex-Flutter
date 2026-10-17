import 'package:texweft_markdown_core/texweft_markdown_core.dart';

/// A read-only deck indexes parsed blocks without copying or rewriting Markdown.
final class PresentationDeck {
  PresentationDeck._(this.document, this.title, this.slides);

  factory PresentationDeck.fromDocument(
    MarkdownDocument document, {
    required String title,
  }) {
    final slides = <PresentationSlide>[];
    final headings = {for (final h in document.headings) h.header.start: h};
    var start = 0;
    MarkdownHeading? heading;
    void append(int end) {
      if (end <= start) return;
      slides.add(
        PresentationSlide(
          title: heading?.title.isNotEmpty == true ? heading!.title : title,
          level: heading?.level ?? 1,
          headingId: heading?.id,
          firstBlock: start,
          endBlock: end,
        ),
      );
    }

    for (var i = 0; i < document.blocks.length; i++) {
      final block = document.blocks[i];
      if (block.kind == MarkdownBlockKind.heading) {
        append(i);
        start = i;
        heading = headings[block.range.start];
      } else if (block.kind == MarkdownBlockKind.rule) {
        append(i);
        start = i + 1;
      }
    }
    append(document.blocks.length);
    if (slides.isEmpty) {
      slides.add(
        PresentationSlide(title: title, level: 1, firstBlock: 0, endBlock: 0),
      );
    }
    return PresentationDeck._(document, title, List.unmodifiable(slides));
  }

  final MarkdownDocument document;
  final String title;
  final List<PresentationSlide> slides;
}

final class PresentationSlide {
  const PresentationSlide({
    required this.title,
    required this.level,
    required this.firstBlock,
    required this.endBlock,
    this.headingId,
  });

  final String title;
  final int level, firstBlock, endBlock;
  final String? headingId;
}
