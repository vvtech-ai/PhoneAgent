import 'package:flutter/material.dart';
import 'native_message_paragraph.dart';
import 'conversation_copy_menu.dart';

/// Shared ordinary text presentation, including explanations owned by a card.
class NativeConversationTextBubble extends StatelessWidget {
  const NativeConversationTextBubble({
    super.key,
    required this.text,
    this.user = false,
    this.bubbleKey,
    this.copyEnabled = false,
    this.fillWidth = false,
  });
  final String text;
  final bool user;
  final bool copyEnabled;
  final bool fillWidth;
  final Key? bubbleKey;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) => Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConversationCopyMenu(
        text: text,
        enabled: copyEnabled,
        child: Container(
          key: bubbleKey,
          width: fillWidth ? (user ? 220 : 260) : null,
          constraints: BoxConstraints(
            minWidth: viewport.maxWidth.clamp(0.0, 44.0),
            maxWidth: user ? 220 : 260,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: user ? null : Colors.white,
            gradient: user
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF007AFF), Color(0xFF0066DD)],
                  )
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(user ? 18 : 4),
              bottomRight: Radius.circular(user ? 4 : 18),
            ),
            boxShadow: user
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      offset: Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: text,
                excludeSemantics: true,
                child: IgnorePointer(
                  child: NativeMessageParagraph(
                    text: text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 22 / 14,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w400,
                      color: user ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
