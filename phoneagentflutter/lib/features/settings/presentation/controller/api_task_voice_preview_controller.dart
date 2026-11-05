import '../../../call_models/domain/system_voice_preview.dart';
import '../../../call_models/presentation/controller/system_voice_preview_controller.dart';
import '../../domain/task_voice.dart';
import 'task_voice_preview_controller.dart';

/// Keep task UI state while sharing the native App's SDK audio-preview lifecycle.
class ApiTaskVoicePreviewController extends TaskVoicePreviewController {
  ApiTaskVoicePreviewController(
    SystemVoicePreviewPort port, {
    required bool Function() isCurrent,
  }) : super(
         (_) =>
             (_, __) => throw StateError('HTTP preview only'),
       ) {
    _preview = SystemVoicePreviewController(
      port,
      isCurrent: isCurrent,
      supports: (id) => id.isNotEmpty,
    );
    _removeListener = _preview.addListener((value) {
      if (mounted) {
        state = TaskVoicePreviewState(
          voice: value.voiceId.isEmpty ? null : _voice,
          error: value.error,
        );
      }
    }, fireImmediately: false);
  }
  late final SystemVoicePreviewController _preview;
  late final void Function() _removeListener;
  TaskVoice? _voice;
  @override
  Future<void> toggle(TaskVoice voice) {
    _voice = voice;
    return _preview.toggle(voice.speaker);
  }

  @override
  Future<void> stop() async {
    await _preview.stop();
  }

  @override
  void dispose() {
    _removeListener();
    _preview.dispose();
    super.dispose();
  }
}
