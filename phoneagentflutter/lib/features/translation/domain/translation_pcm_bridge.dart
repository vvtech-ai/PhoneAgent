import 'dart:typed_data';
import 'translation_realtime_event.dart';

/// Single-use duplex hardware. Capture is 16k PCM16 mono; playback keeps the
/// server sample rate. No protocol, permission prompts or call commands here.
abstract interface class TranslationPcmBridge {
  Future<void> start();
  Future<Uint8List?> read();
  Future<void> play(TranslationAudio audio);
  Future<void> setSpeaker(bool enabled);
  Future<void> close();
}

/// Optional iOS call preparation. Hardware is ready, capture delivery remains
/// suspended until start(), and no business audio is transmitted here.
abstract interface class TranslationPcmPreparation {
  Future<void> prepareCallAudio();
}

/// Optional queued playback capability; drain completes after actual playback.
abstract interface class TranslationPcmDrain {
  Future<void> drain();
}

abstract interface class TranslationPcmQueue implements TranslationPcmDrain {
  void enableQueuedPlayback();
}

abstract interface class TranslationPcmStatistics {
  Future<Map<String, int>> playbackStatistics();
}
