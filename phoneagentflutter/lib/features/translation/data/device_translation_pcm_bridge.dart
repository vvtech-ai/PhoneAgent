import 'dart:typed_data';
import '../../../core/audio/pcm_capture.dart';
import '../../conversation/data/voice/device_pcm_capture.dart';
import '../../conversation/data/voice/device_pcm_output.dart';
import '../domain/translation_pcm_bridge.dart';
import '../domain/translation_call_audio_lease.dart';
import '../domain/translation_realtime_event.dart';

/// Owns one capture and the current playback format, not protocol or call state.
class DeviceTranslationPcmBridge
    implements
        TranslationPcmBridge,
        TranslationPcmPreparation,
        TranslationPcmQueue,
        TranslationPcmStatistics {
  DeviceTranslationPcmBridge({
    DevicePcmCapture? capture,
    this.callAudio,
    DevicePcmOutput Function()? createOutput,
  }) : capture =
           capture ??
           DevicePcmCapture(duplex: true, backgroundCallId: callAudio?.id),
       createOutput =
           createOutput ??
           (() => DevicePcmOutput(
             communication: true,
             duplex: true,
             backgroundCallId: callAudio?.id,
           ));
  final TranslationCallAudioLease? callAudio;
  final DevicePcmCapture capture;
  final DevicePcmOutput Function() createOutput;
  DevicePcmOutput? _output;
  int _rate = 0;
  bool _closed = false, _speaker = false, _queued = false;
  bool _prepared = false;
  Future<void>? _preparation;

  @override
  Future<void> prepareCallAudio() => _preparation ??= _prepareCallAudio();

  Future<void> _prepareCallAudio() async {
    _check();
    await callAudio?.acquire();
    _check();
    await capture.prepareDuplexCall();
    _check();
    final output = _output = createOutput();
    output.queuedTranslation = _queued;
    await output.start(16000);
    _check();
    await output.communicationRoute(select: _speaker ? 'speaker' : 'earpiece');
    _check();
    _rate = 16000;
    _prepared = true;
  }

  @override
  void enableQueuedPlayback() {
    _check();
    if (_output != null) throw StateError('Playback already started');
    _queued = true;
  }

  Future<void>? _cleanup;
  void _check() {
    if (_closed) throw const PcmCaptureFailure('capture_cancelled');
  }

  @override
  Future<void> start() async {
    _check();
    if (_preparation != null) {
      await _preparation;
      _check();
      if (!_prepared) throw const PcmCaptureFailure('capture_start_failed');
      await capture.resumeDuplexCall();
      _check();
      return;
    }
    await callAudio?.acquire();
    _check();
    await capture.start();
    _check();
  }

  @override
  Future<Uint8List?> read() => capture.read();
  @override
  Future<void> play(TranslationAudio audio) async {
    _check();
    if (_output == null || audio.sampleRate != _rate) {
      await _output?.stop();
      _check();
      final output = _output = createOutput();
      output.queuedTranslation = _queued;
      await output.start(audio.sampleRate);
      _check();
      await output.communicationRoute(
        select: _speaker ? 'speaker' : 'earpiece',
      );
      _check();
      _rate = audio.sampleRate;
    }
    await _output!.enqueue(audio.pcm);
    _check();
  }

  @override
  Future<void> drain() async {
    _check();
    await _output?.drain();
    _check();
  }

  @override
  Future<Map<String, int>> playbackStatistics() async =>
      await _output?.statistics() ?? {};

  @override
  Future<void> setSpeaker(bool enabled) async {
    _check();
    // Capture owns the communication session even before first downlink audio.
    await capture.setDuplexSpeaker(enabled);
    _check();
    _speaker = enabled;
  }

  @override
  Future<void> close() {
    _closed = true;
    return _cleanup ??= _release();
  }

  Future<void> _release() async {
    var failed = false;
    try {
      await _output?.stop();
    } catch (_) {
      failed = true;
    }
    try {
      await capture.stop();
    } catch (_) {
      failed = true;
    }
    if (failed) {
      _cleanup = null;
      throw StateError('Duplex release failed');
    }
    try {
      await callAudio?.release();
    } catch (_) {
      _cleanup = null;
      rethrow;
    }
  }
}
