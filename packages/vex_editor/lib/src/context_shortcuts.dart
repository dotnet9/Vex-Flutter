import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class MarkdownContextShortcuts extends StatelessWidget {
  const MarkdownContextShortcuts({
    super.key,
    required this.onShow,
    required this.child,
  });

  final bool Function()? onShow;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent || onShow == null) {
        return KeyEventResult.ignored;
      }
      final keyboard = HardwareKeyboard.instance;
      final matches = const [
        SingleActivator(LogicalKeyboardKey.contextMenu),
        SingleActivator(LogicalKeyboardKey.f10, shift: true),
      ].any((shortcut) => shortcut.accepts(event, keyboard));
      return matches && onShow!()
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    },
    child: child,
  );
}

Offset? markdownCaretMenuPosition(BuildContext context) {
  RenderEditable? editable;
  void visit(RenderObject object) {
    if (object is RenderEditable && object.hasFocus) {
      editable = object;
    } else if (editable == null) {
      object.visitChildren(visit);
    }
  }

  final root = context.findRenderObject();
  if (root != null) visit(root);
  final selection = editable?.selection;
  if (editable == null || selection == null || !selection.isValid) return null;
  final rect = editable!.getLocalRectForCaret(selection.extent);
  final local = Offset(
    rect.left.clamp(0, editable!.size.width),
    rect.bottom.clamp(0, editable!.size.height),
  );
  return editable!.localToGlobal(local);
}
