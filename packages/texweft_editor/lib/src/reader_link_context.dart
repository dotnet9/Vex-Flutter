part of 'reader.dart';

class _ReaderParseBoundary extends MarkdownElementBuilder {
  _ReaderParseBoundary(this.onParse);
  final VoidCallback onParse;
  @override
  bool isBlockElement() {
    onParse();
    return false;
  }
}

/// Text spans remain mergeable into one paragraph. Recognizers own gestures,
/// not a widget around each link that would introduce a separate wrapping box.
class _ContextLinkRecognizer extends TapGestureRecognizer {
  _ContextLinkRecognizer(ValueChanged<Offset> show) {
    _longPress.onLongPressStart = (details) => show(details.globalPosition);
  }
  final _longPress = LongPressGestureRecognizer();
  @override
  void addPointer(PointerDownEvent event) {
    super.addPointer(event);
    _longPress.addPointer(event);
  }

  @override
  void dispose() {
    _longPress.dispose();
    super.dispose();
  }
}

class _LinkRecognizerHost extends StatefulWidget {
  const _LinkRecognizerHost({required this.reader, required this.builder});
  final MarkdownReader reader;
  final Widget Function(_LinkRecognizerHostState links) builder;
  @override
  State<_LinkRecognizerHost> createState() => _LinkRecognizerHostState();
}

class _LinkRecognizerHostState extends State<_LinkRecognizerHost> {
  final _recognizers = <(String, int), _ContextLinkRecognizer>{};
  _ContextLinkRecognizer recognizer(
    String url,
    int occurrence,
    String text,
    String title,
  ) => _recognizers.putIfAbsent((url, occurrence), () {
    void show(Offset position) =>
        widget.reader.onMediaContext?.call(url, false, occurrence, position);
    return _ContextLinkRecognizer(show)
      ..onTap = (() => widget.reader.onTapLink?.call(text, url, title))
      ..onSecondaryTapUp = (event) => show(event.globalPosition);
  });

  void _clear() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void didUpdateWidget(_LinkRecognizerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reader.data != oldWidget.reader.data ||
        widget.reader.preferences != oldWidget.reader.preferences) {
      _clear();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(this);

  @override
  void dispose() {
    _clear();
    super.dispose();
  }
}
