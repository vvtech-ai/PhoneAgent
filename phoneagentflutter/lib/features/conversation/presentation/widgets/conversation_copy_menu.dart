import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/native_notice.dart';

/// Platform clipboard presentation for completed ordinary messages only.
class ConversationCopyMenu extends StatefulWidget {
  const ConversationCopyMenu({
    super.key,
    required this.text,
    required this.enabled,
    required this.child,
  });
  final String text;
  final bool enabled;
  final Widget child;
  @override
  State<ConversationCopyMenu> createState() => _CopyMenuState();
}

class _CopyMenuState extends State<ConversationCopyMenu> {
  bool _showing = false;
  Future<void> _show(LongPressStartDetails details) async {
    if (_showing || !widget.enabled || widget.text.trim().isEmpty) return;
    _showing = true;
    final original = widget.text;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final point = overlay.globalToLocal(details.globalPosition);
    final selected = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(point.dx, point.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [PopupMenuItem(value: true, child: Text('复制'))],
    );
    _showing = false;
    if (!mounted ||
        selected != true ||
        !widget.enabled ||
        widget.text != original) {
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: original));
      if (mounted) showNativeNotice(context, '已复制');
    } on PlatformException {
      if (mounted) showNativeNotice(context, '复制失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onLongPressStart: widget.enabled ? _show : null,
    child: widget.child,
  );
}
