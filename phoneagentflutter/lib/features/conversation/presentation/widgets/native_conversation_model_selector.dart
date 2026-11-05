import 'package:flutter/material.dart';
import '../../../../core/design/conversation_tokens.dart';

class NativeConversationModelSelector extends StatefulWidget {
  const NativeConversationModelSelector({
    super.key,
    required this.name,
    required this.onPressed,
  });
  final String name;
  final VoidCallback? onPressed;

  @override
  State<NativeConversationModelSelector> createState() => _SelectorState();
}

class _SelectorState extends State<NativeConversationModelSelector> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: widget.onPressed != null,
    label: '通话模型：${widget.name}',
    onTap: widget.onPressed,
    excludeSemantics: true,
    child: Listener(
      onPointerDown: widget.onPressed == null ? null : (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapCancel: () => _press(false),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.bottomLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              // Container adds the one-point border to this padding.
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xE6F8F8FA),
                border: Border.all(color: const Color(0xD6FFFFFF)),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                color: _pressed ? const Color(0x08111111) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        letterSpacing:
                            .5 *
                            MediaQuery.textScalerOf(context).scale(12) /
                            12,
                        fontWeight: FontWeight.w400,
                        color: widget.onPressed != null
                            ? ConversationTokens.model
                            : ConversationTokens.inactiveLabel,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: widget.onPressed != null
                        ? const Color(0xFF8A94A6)
                        : ConversationTokens.inactiveLabel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
