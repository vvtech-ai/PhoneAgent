import '../../../../core/audio/audio_playback_focus.dart';
import '../../../settings/data/preview_pcm_output.dart';
import '../../../settings/data/preview_voice_socket.dart';
import '../../domain/voice/reply_speech_playback.dart';
import 'conversation_tts_stream.dart';
import 'task_tts_session.dart';

/// Isolated synthetic boundaries around the production reply playback pipeline.
class PreviewReplySpeech {
  final focus = AudioPlaybackFocus();
  PreviewPcmOutput? output;
  ReplySpeechPlayback create(bool Function() current, void Function() changed) {
    final device = output = PreviewPcmOutput();
    return ConversationTtsStream(
      endpoint: Uri.parse('ws://synthetic.invalid/tts'),
      output: device,
      focus: focus,
      isCurrent: current,
      onChanged: changed,
      createSession: () => TaskTtsSession(
        connector: (_) async {
          final socket = PreviewVoiceSocket();
          socket.emit('{"type":"ready"}');
          return socket;
        },
      ),
    );
  }
}
