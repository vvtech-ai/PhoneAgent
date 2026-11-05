import 'dart:async';
import 'dart:typed_data';
import '../../../../core/audio/audio_playback_focus.dart';
import '../../../../core/audio/focused_pcm_output.dart';
import '../../../../core/audio/pcm_output.dart';
import '../../../../core/audio/pcm_playback_queue.dart';
import '../../domain/voice/voice_gateway_event.dart';
import 'task_tts_session.dart';

/// A single synthesis utterance plus actual device playback and audio ownership.
/// Conversation segmentation/signal routing belongs to the caller, not this class.
class TaskTtsPlayback {
  TaskTtsPlayback({
    required this.tts,
    required PcmOutput output,
    required AudioPlaybackFocus focus,
    required this.isCurrent,
    this.onChanged,
  }) {
    playback = PcmPlaybackQueue(
      output: FocusedPcmOutput(
        output,
        focus,
        isCurrent: () => !_cancelled && isCurrent(),
        onInterrupted: () => unawaited(cancel()),
      ),
      sampleRateHz: 24000,
      capacityBytes: tts.maxAudioBytes + 24000,
      onChanged: _changed,
    );
  }
  final TaskTtsSession tts;
  final bool Function() isCurrent;
  final void Function()? onChanged;
  late final PcmPlaybackQueue playback;
  StreamSubscription<VoiceGatewayEvent>? _subscription;
  bool _started = false, _cancelled = false, _audio = false;
  bool synthesisComplete = false, softTimeout = false;
  int audioBytes = 0;
  Future<PcmPlaybackPhase> get finished => playback.finished;

  void _changed() {
    if (playback.phase == PcmPlaybackPhase.failed) unawaited(tts.cancel());
    onChanged?.call();
  }

  Future<void> start(
    Uri endpoint, {
    required String text,
    required String speaker,
  }) async {
    if (_started || _cancelled) throw StateError('TTS playback already used');
    _started = true;
    if (!isCurrent()) {
      await cancel();
      return;
    }
    _subscription = tts.events.listen(
      _event,
      onError: (Object _) => unawaited(playback.fail('tts_failed')),
      onDone: () {
        if (!_cancelled && !synthesisComplete) {
          unawaited(playback.fail('tts_closed'));
        }
      },
    );
    try {
      await tts.start(endpoint, text: text, speaker: speaker);
    } catch (_) {
      if (!_cancelled) await playback.fail('tts_failed');
    }
  }

  void _event(VoiceGatewayEvent event) {
    if (_cancelled || !isCurrent()) {
      unawaited(cancel());
      return;
    }
    try {
      if (event is VoicePcmChunk) {
        if (!_audio) {
          _audio = true;
          playback.add(Uint8List(15360)); // v65 24k start guard, 320ms.
        }
        audioBytes += event.bytes.length;
        playback.add(event.bytes);
      } else if (event is VoiceSynthesisComplete) {
        synthesisComplete = true;
        softTimeout = event.softTimeout;
        if (_audio) playback.add(Uint8List(2880)); // v65 60ms tail padding.
        playback.complete();
        unawaited(tts.cancel());
      } else if (event is VoiceGatewayFailure) {
        unawaited(playback.fail('tts_failed'));
      }
    } catch (_) {
      unawaited(playback.fail('tts_output_failed'));
    }
    onChanged?.call();
  }

  Future<void> cancel() async {
    _cancelled = true;
    // Invalidate playback synchronously, before native stop rejects play calls.
    final stopping = playback.stop();
    final subscription = _subscription;
    _subscription = null;
    final transportStop = tts.cancel();
    await Future.wait([
      stopping,
      transportStop,
      if (subscription != null) subscription.cancel(),
    ]);
  }
}
