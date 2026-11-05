import 'package:flutter/material.dart';
import '../../../../core/design/conversation_tokens.dart';
import '../controller/voice_input_state.dart';
import 'voice_composer_binding.dart';
import 'native_voice_finalizing_dots.dart';
import 'native_voice_press_feedback.dart';

/// Pointer-down starts immediately like v65 (no long-press recognizer delay).
class VoiceHoldButton extends StatefulWidget {
  const VoiceHoldButton({
    super.key,
    required this.binding,
    required this.enabled,
    required this.icon,
    required this.onUnavailable,
  });
  final VoiceComposerBinding? binding;
  final bool enabled;
  final Widget icon;
  final VoidCallback onUnavailable;
  @override
  State<VoiceHoldButton> createState() => _VoiceHoldButtonState();
}

class _VoiceHoldButtonState extends State<VoiceHoldButton> {
  int? _pointer;
  double _startY = 0;
  bool _cancelArmed = false;
  int _cancelEpoch = 0;
  @override
  void didUpdateWidget(covariant VoiceHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pointer != null &&
        (!widget.enabled ||
            widget.binding?.state.canPress == true ||
            widget.binding?.state.phase == VoiceInputPhase.finalizing ||
            widget.binding?.state.phase == VoiceInputPhase.stopping)) {
      // An external timeout/error already finished the input; ignore later up.
      _pointer = null;
      _cancelArmed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.binding?.state;
    final finalizing =
        state?.phase == VoiceInputPhase.finalizing ||
        state?.phase == VoiceInputPhase.stopping;
    final active =
        widget.enabled &&
        !finalizing &&
        (_pointer != null || state?.phase == VoiceInputPhase.recording);
    final label = finalizing
        ? '识别中'
        : _cancelArmed
        ? '松开取消'
        : active
        ? '松开发送，上滑取消'
        : '按住说话';
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      button: true,
      enabled: widget.enabled && !finalizing,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointer != null || !widget.enabled || finalizing) return;
          final binding = widget.binding;
          if (binding == null) {
            widget.onUnavailable();
            return;
          }
          if (!binding.state.canPress) return;
          setState(() {
            _pointer = event.pointer;
            _startY = event.position.dy;
            _cancelArmed = false;
          });
          binding.onGesturePress?.call(event.timeStamp);
          binding.onPress();
        },
        onPointerMove: (event) {
          if (event.pointer != _pointer) return;
          setState(() => _cancelArmed = event.position.dy - _startY <= -58);
        },
        onPointerUp: (event) {
          if (event.pointer != _pointer) return;
          final cancel = event.position.dy - _startY <= -58;
          setState(() {
            _pointer = null;
            _cancelArmed = false;
            if (cancel) _cancelEpoch++;
          });
          if (cancel) {
            widget.binding?.onGestureCancel?.call();
            widget.binding?.onCancel();
          } else if (widget.binding?.onGestureRelease?.call(event.timeStamp) ==
              false) {
            widget.binding?.onCancel();
          } else {
            widget.binding?.onRelease();
          }
        },
        onPointerCancel: (event) {
          if (event.pointer != _pointer) return;
          setState(() {
            _pointer = null;
            _cancelArmed = false;
            _cancelEpoch++;
          });
          widget.binding?.onGestureCancel?.call();
          widget.binding?.onCancel();
        },
        child: NativeVoicePressFeedback(
          active: active,
          cancel: _cancelArmed,
          cancelEpoch: _cancelEpoch,
          guideHint: widget.binding?.guideHint ?? '',
          child: AnimatedScale(
            scale: active ? 1.4 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            child: Container(
              key: const ValueKey('conversation-voice-button'),
              width: ConversationTokens.voiceButton,
              height: ConversationTokens.voiceButton,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _cancelArmed
                    ? const LinearGradient(
                        colors: [Color(0xFFFF5A52), Color(0xFFE53935)],
                      )
                    : active
                    ? const LinearGradient(
                        colors: [Color(0xFF34C759), Color(0xFF23A652)],
                      )
                    : ConversationTokens.actionGradient,
              ),
              child: Center(
                child: finalizing
                    ? const NativeVoiceFinalizingDots()
                    : widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
