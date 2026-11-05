import 'reply_speech_playback.dart';

/// Optional observation port; contains no text and performs no audio actions.
abstract interface class ReplySpeechStartObserver {
  void observeSpeechStart(DateTime observedAt, int elapsedMs);
}

/// One live reply's original observation, handed off only when speech is queued.
class ReplySpeechStart {
  ReplySpeechStart()
    : observedAt = DateTime.now().toUtc(),
      _watch = Stopwatch()..start();
  final DateTime observedAt;
  final Stopwatch _watch;
  bool _reported = false;

  void reportTo(ReplySpeechPlayback playback) {
    if (_reported) return;
    _reported = true;
    _watch.stop();
    if (playback is! ReplySpeechStartObserver) return;
    try {
      (playback as ReplySpeechStartObserver).observeSpeechStart(
        observedAt,
        _watch.elapsedMilliseconds,
      );
    } catch (_) {
      // Diagnostic adapters cannot prevent the original synthesis handoff.
    }
  }
}
