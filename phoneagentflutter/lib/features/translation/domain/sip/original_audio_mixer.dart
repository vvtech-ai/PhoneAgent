import 'dart:typed_data';
import 'original_audio_level.dart';
import 'sip_pcm_frame_queue.dart';
import 'translation_audio_ducking.dart';

/// One-direction native original/translation mix, driven by the media clock.
class OriginalAudioMixer {
  OriginalAudioMixer({
    required double ratio,
    required double pureGain,
    required bool dynamicBoost,
    required bool responseBoundarySupported,
  }) : _level = OriginalAudioLevel(
         ratio: ratio,
         pureGain: pureGain,
         maxGain: dynamicBoost ? 8 : ratio,
       ),
       _ducking = TranslationAudioDucking(
         responseBoundarySupported: responseBoundarySupported,
       ),
       _lastGain = pureGain;
  final OriginalAudioLevel _level;
  final TranslationAudioDucking _ducking;
  final _original = SipPcmFrameQueue(maxBytes: 64000, prebufferBytes: 640);
  final _translated = SipPcmFrameQueue(prebufferBytes: 640);
  double _lastGain, _attackStart = 0, _releaseStart = 0;
  TranslationDuckingState _previous = TranslationDuckingState.original;

  void original(Uint8List pcm) => _original.enqueue(pcm);
  void translated(Uint8List pcm, int now) {
    _translated.enqueue(pcm);
    _ducking.translated(now);
  }

  void responseDone(int now) {
    _translated.markDone();
    _ducking.responseDone(now);
  }

  Uint8List? nextFrame(int now) {
    final translated = _translated.canDrain ? _translated.nextFrame() : null;
    final original = _original.canDrain ? _original.nextFrame() : null;
    if (translated != null &&
        (_ducking.state == TranslationDuckingState.original ||
            _ducking.state == TranslationDuckingState.release)) {
      _ducking.translated(now);
    }
    final state = _ducking.next(
      now,
      queued: translated != null || _translated.canDrain,
    );
    var gain = _level.next(
      original,
      translated,
      active: state != TranslationDuckingState.original,
    );
    if (state == TranslationDuckingState.attack) {
      if (_previous != state) {
        _attackStart = _lastGain;
      }
      gain = _attackStart + (gain - _attackStart) * _ducking.progress(now, 40);
    } else if (state == TranslationDuckingState.release) {
      if (_previous != state) {
        _releaseStart = _lastGain;
      }
      gain =
          _releaseStart +
          (_level.pureGain - _releaseStart) * _ducking.progress(now, 350);
    }
    _lastGain = gain;
    _previous = state;
    if (translated == null && original == null) {
      return null;
    }
    return OriginalAudioLevel.mix(original, translated, gain);
  }

  void clear() {
    _original.clear();
    _translated.clear();
  }
}
