import 'package:flutter/foundation.dart';
import '../controller/voice_input_state.dart';

class VoiceComposerBinding {
  const VoiceComposerBinding({
    required this.state,
    required this.onPress,
    required this.onRelease,
    required this.onCancel,
    this.speechStatus = '',
    this.canInterruptReply = false,
    this.aiSpeechEnabled = true,
    this.onToggleSpeech,
    this.onStopSpeech,
    this.guideHint = '',
    this.preferenceNotice = '',
    this.onGesturePress,
    this.onGestureRelease,
    this.onGestureCancel,
  });
  final VoiceInputState state;
  final String speechStatus;
  final bool canInterruptReply;
  final VoidCallback onPress, onRelease, onCancel;
  final bool aiSpeechEnabled;
  final String guideHint, preferenceNotice;
  final VoidCallback? onToggleSpeech, onStopSpeech, onGestureCancel;
  final void Function(Duration)? onGesturePress;
  final bool Function(Duration)? onGestureRelease;
}
