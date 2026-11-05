import 'dart:typed_data';
import 'audio_playback_focus.dart';
import 'audio_resource_coordinator.dart';
import 'pcm_output.dart';

class FocusedPcmOutput implements PcmOutput {
  FocusedPcmOutput(
    this.delegate,
    this.focus, {
    required this.isCurrent,
    this.onInterrupted,
  });
  final PcmOutput delegate;
  final AudioPlaybackFocus focus;
  final bool Function() isCurrent;
  final void Function()? onInterrupted;
  AudioLease? _lease;
  Future<void>? _cleanup;
  bool _closed = false, _used = false;
  bool get _current => !_closed && isCurrent();
  void _check() {
    if (!_current) throw const PcmOutputFailure('output_cancelled');
  }

  @override
  Future<void> start(int sampleRateHz) async {
    _check();
    if (_used) throw const PcmOutputFailure('output_used');
    _used = true;
    try {
      _lease = await focus.acquire(
        owner: 'conversation-tts',
        stop: (_) {
          onInterrupted?.call();
          return stop();
        },
        isCurrent: () => _current,
      );
      _check();
      await delegate.start(sampleRateHz);
      _check();
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  @override
  Future<void> play(Uint8List bytes) async {
    _check();
    final lease = _lease;
    if (lease == null || !focus.owns(lease)) {
      throw const PcmOutputFailure('output_cancelled');
    }
    await delegate.play(bytes);
    _check();
  }

  @override
  Future<void> stop() async {
    _closed = true;
    await (_cleanup ??= _release());
    final lease = _lease;
    if (lease != null) {
      focus.release(lease);
      _lease = null;
    }
  }

  Future<void> _release() async {
    try {
      await delegate.stop();
    } catch (_) {
      _cleanup = null;
      rethrow;
    }
  }
}
