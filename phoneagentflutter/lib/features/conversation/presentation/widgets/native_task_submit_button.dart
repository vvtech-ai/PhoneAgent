import 'package:flutter/material.dart';
import '../../../../core/design/conversation_tokens.dart';
import 'native_voice_finalizing_dots.dart';

/// v66 input-row send/stop control. No draft mutation or stop lifecycle here.
class NativeTaskSubmitButton extends StatelessWidget {
  const NativeTaskSubmitButton({
    super.key,
    required this.canSend,
    required this.onSend,
    this.onStop,
    this.stopping = false,
    this.buttonKey = const ValueKey('send-text'),
    this.voiceControl = false,
  });
  final bool canSend, stopping;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final Key buttonKey;
  final bool voiceControl;

  @override
  Widget build(BuildContext context) {
    final stop = onStop != null || stopping;
    final voice = voiceControl && stop;
    final action = stop
        ? (stopping ? null : onStop)
        : (canSend ? onSend : null);
    return Semantics(
      container: true,
      button: true,
      enabled: action != null,
      label: stop ? '停止当前处理' : '发送文字',
      onTap: action,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: voice ? ConversationTokens.actionGradient : null,
        ),
        child: IconButton.filled(
          key: stop ? const ValueKey('stop-current-processing') : buttonKey,
          onPressed: action,
          style: IconButton.styleFrom(
            backgroundColor: voice
                ? Colors.transparent
                : Color(stop ? 0xFFE7EAEE : 0xFF0A84FF),
            foregroundColor: stop && !voice
                ? const Color(0xFF475467)
                : Colors.white,
            disabledBackgroundColor: voice
                ? Colors.transparent
                : Color(stop ? 0xFFE7EAEE : 0xFFE3EAF3),
            disabledForegroundColor: const Color(0xFF98A2B3),
            fixedSize: Size.square(voice ? 56 : 40),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: stopping
              ? voice
                    ? const NativeVoiceFinalizingDots()
                    : const ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Color(0xFF475467),
                          BlendMode.srcIn,
                        ),
                        child: NativeVoiceFinalizingDots(),
                      )
              : Icon(
                  stop ? Icons.stop_rounded : Icons.send_rounded,
                  size: voice ? 25 : 20,
                ),
        ),
      ),
    );
  }
}
