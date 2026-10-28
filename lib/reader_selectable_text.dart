import 'text_pagination.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class _SpanController extends TextEditingController {
  _SpanController(this.span) : super(text: span.toPlainText());
  TextSpan span;
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => span;
}

/// Read-only selection with native handles. Double tap belongs to fullscreen;
/// ordinary drags are left to the reader's directional pager.
class ReaderSelectableText extends StatefulWidget {
  const ReaderSelectableText({
    super.key,
    required this.span,
    required this.style,
    required this.direction,
    required this.menuBuilder,
    this.onTap,
    this.onDoubleTap,
  });
  final TextSpan span;
  final TextStyle style;
  final TextDirection direction;
  final EditableTextContextMenuBuilder menuBuilder;
  final VoidCallback? onTap, onDoubleTap;
  @override
  State<ReaderSelectableText> createState() => _ReaderSelectableTextState();
}

class _ReaderGestures extends TextSelectionGestureDetectorBuilder {
  _ReaderGestures(TextSelectionGestureDetectorBuilderDelegate delegate)
    : super(delegate: delegate);
  void down(TapDownDetails details) => onTapDown(
    TapDragDownDetails(
      consecutiveTapCount: 1,
      globalPosition: details.globalPosition,
      localPosition: details.localPosition,
      kind: details.kind ?? PointerDeviceKind.touch,
    ),
  );
  void longStart(LongPressStartDetails details) =>
      onSingleLongTapStart(details);
  void longMove(LongPressMoveUpdateDetails details) =>
      onSingleLongTapMoveUpdate(details);
  void longEnd(LongPressEndDetails details) => onSingleLongTapEnd(details);
  void longCancel() => onSingleLongTapCancel();
}

class _ReaderSelectableTextState extends State<ReaderSelectableText>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final editableTextKey = GlobalKey<EditableTextState>();
  @override
  bool get forcePressEnabled => false;
  @override
  bool get selectionEnabled => true;
  late final controller = _SpanController(widget.span);
  final focus = FocusNode();
  late final gestures = _ReaderGestures(this);
  bool handles = false;
  @override
  void didUpdateWidget(ReaderSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.span = widget.span;
    final text = widget.span.toPlainText();
    if (controller.text != text) {
      handles = false;
      controller.value = TextEditingValue(text: text);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTapDown: gestures.down,
    onTap: () {
      if (controller.selection.isValid && !controller.selection.isCollapsed) {
        editableTextKey.currentState?.hideToolbar();
        controller.selection = TextSelection.collapsed(
          offset: controller.selection.end,
        );
        setState(() => handles = false);
        focus.unfocus();
      } else {
        widget.onTap?.call();
      }
    },
    onDoubleTap: widget.onDoubleTap,
    onLongPressStart: (details) {
      focus.requestFocus();
      gestures.longStart(details);
    },
    onLongPressMoveUpdate: gestures.longMove,
    onLongPressEnd: gestures.longEnd,
    onLongPressCancel: gestures.longCancel,
    child: EditableText(
      key: editableTextKey,
      controller: controller,
      focusNode: focus,
      style: widget.style,
      readOnly: true,
      showCursor: false,
      cursorWidth: readingCursorWidth,
      forceLine: false,
      maxLines: null,
      strutStyle: readingStrutStyle(widget.style),
      textHeightBehavior: readingTextHeightBehavior,
      textDirection: widget.direction,
      textScaler: MediaQuery.textScalerOf(context),
      cursorColor: Theme.of(context).colorScheme.primary,
      backgroundCursorColor: Colors.grey,
      selectionColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: .3),
      showSelectionHandles: handles,
      selectionControls: materialTextSelectionHandleControls,
      onSelectionChanged: (selection, cause) {
        final show = !selection.isCollapsed && selection.isValid;
        if (handles != show) setState(() => handles = show);
      },
      rendererIgnoresPointer: true,
      enableInteractiveSelection: true,
      scrollPhysics: const NeverScrollableScrollPhysics(),
      scrollPadding: EdgeInsets.zero,
      contextMenuBuilder: widget.menuBuilder,
    ),
  );
}
