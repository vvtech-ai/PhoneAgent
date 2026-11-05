import 'dart:typed_data';
import 'audio_playback_focus.dart';
import 'audio_resource_coordinator.dart';
import 'pcm_capture.dart';

/// A microphone cannot be stolen by a playback tap or identity SDK start.
/// Account/host stopAll can stop it, but only actual shutdown frees the lease.
class FocusedPcmCapture implements PcmCapture {
  FocusedPcmCapture(this.delegate, this.focus, {required this.isCurrent});
  final PcmCapture delegate;
  final AudioPlaybackFocus focus;
  final bool Function() isCurrent;
  AudioLease? _lease;
  Future<void>? _cleanup;
  bool _closed = false, _used = false;
  bool get _current => !_closed && isCurrent();

  void _check() {
    if (!_current) throw const PcmCaptureFailure('capture_cancelled');
  }

  @override
  Future<void> start() async {
    _check();
    if (_used) throw const PcmCaptureFailure('capture_used');
    _used = true;
    try {
      _lease = await focus.acquire(
        owner: 'conversation-capture',
        stop: (_) => stop(),
        isCurrent: () => _current,
        interruptible: false,
      );
      _check();
      await delegate.start();
      _check();
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  @override
  Future<Uint8List?> read() async {
    _check();
    final lease = _lease;
    if (lease == null || !focus.owns(lease)) {
      throw const PcmCaptureFailure('capture_cancelled');
    }
    final bytes = await delegate.read();
    _check();
    return bytes;
  }

  @override
  Future<void> stop() async {
    _closed = true;
    await (_cleanup ??= _releaseNative());
    // Also releases a lease granted just after an earlier stop completed.
    final lease = _lease;
    if (lease != null) {
      focus.release(lease);
      _lease = null;
    }
  }

  Future<void> _releaseNative() async {
    try {
      await delegate.stop();
    } catch (_) {
      _cleanup = null;
      rethrow;
    }
  }
}
