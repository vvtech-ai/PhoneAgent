import '../../../core/audio/audio_playback_focus.dart';
import '../../../core/audio/audio_resource_coordinator.dart';
import '../domain/clone_verification.dart';

/// Business cancellation and native media release are intentionally separate.
class FocusedIdentityCapturePort implements IdentityCapturePort {
  FocusedIdentityCapturePort(
    this.delegate,
    this.focus, {
    required this.waitForRelease,
    required this.isCurrent,
  });
  final IdentityCapturePort delegate;
  final AudioPlaybackFocus focus;
  final Future<void> Function() waitForRelease;
  final bool Function() isCurrent;
  AudioLease? _lease;
  Future<void>? _cleanup;
  bool _closed = false, _used = false;
  bool get _current => !_closed && isCurrent();

  void _check() {
    if (!_current) throw StateError('Capture no longer current');
  }

  @override
  Future<String> prepare() async {
    _check();
    final meta = await delegate.prepare();
    _check();
    return meta;
  }

  @override
  Future<IdentityCaptureResult> capture(String certifyId) async {
    _check();
    if (_used) throw StateError('Capture already started');
    _used = true;
    late IdentityCaptureResult result;
    try {
      final lease = await focus.acquire(
        owner: 'identity-capture',
        stop: (_) => abort(),
        isCurrent: () => _current,
        interruptible: false,
      );
      _lease = lease;
      _check();
      result = await delegate.capture(certifyId);
      _check();
    } finally {
      await _finish();
    }
    _check();
    return result;
  }

  Future<void> _finish() async {
    // Capture can receive its lease just after an earlier abort started.
    // Releasing is outside the single-flight operation to include that lease.
    await (_cleanup ??= _releaseNative());
    final lease = _lease;
    if (lease != null) {
      focus.release(lease);
      _lease = null;
    }
  }

  Future<void> _releaseNative() async {
    try {
      await Future.sync(delegate.abort);
      await waitForRelease();
    } catch (_) {
      _cleanup = null; // Retain lease; allow explicit stop to retry cleanup.
      rethrow;
    }
  }

  @override
  Future<void> abort() {
    _closed = true;
    return _finish();
  }
}
