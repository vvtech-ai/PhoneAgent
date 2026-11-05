import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'native_task_submit_button.dart';
import 'voice_composer_binding.dart';

/// Adds the 300ms speech interruption gesture to the existing shared button.
class SpeechStopHoldControl extends StatefulWidget {
  const SpeechStopHoldControl({
    super.key,
    required this.binding,
    required this.canStart,
    required this.onHoldChanged,
    this.onStop,
  });
  final VoiceComposerBinding? binding;
  final bool canStart;
  final ValueChanged<bool> onHoldChanged;
  final VoidCallback? onStop;
  @override
  State<SpeechStopHoldControl> createState() => _SpeechStopHoldControlState();
}

class _SpeechStopHoldControlState extends State<SpeechStopHoldControl> {
  VoiceComposerBinding? _held;
  bool _cancelArmed = false;
  void _start(LongPressStartDetails _) {
    final binding = widget.binding;
    if (!widget.canStart || binding == null || !binding.state.canPress) return;
    _held = binding;
    _cancelArmed = false;
    widget.onHoldChanged(true);
    // The recognizer proves a 300ms hold; guide timestamps are relative.
    binding.onGesturePress?.call(Duration.zero);
    binding.onStopSpeech?.call();
    binding.onPress();
  }

  void _end({bool cancelled = false}) {
    final binding = _held;
    _held = null;
    if (binding == null) return;
    if (cancelled || _cancelArmed) {
      binding.onGestureCancel?.call();
      binding.onCancel();
    } else {
      binding.onGestureRelease?.call(const Duration(milliseconds: 300));
      binding.onRelease();
    }
    widget.onHoldChanged(false);
  }

  @override
  void dispose() {
    _held?.onGestureCancel?.call();
    _held?.onCancel();
    _held = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 300),
            ),
            (recognizer) => recognizer
              ..onLongPressStart = _start
              ..onLongPressMoveUpdate = (details) {
                _cancelArmed = details.offsetFromOrigin.dy <= -58;
              }
              ..onLongPressEnd = (_) {
                _end();
              }
              ..onLongPressCancel = () {
                _end(cancelled: true);
              },
          ),
    },
    child: NativeTaskSubmitButton(
      voiceControl: true,
      canSend: false,
      onSend: () {},
      onStop: widget.binding?.onStopSpeech ?? widget.onStop,
    ),
  );
}
