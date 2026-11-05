import 'dart:async';
import '../../voice_clone/domain/clone_verification.dart';

/// Synthetic vendor lifecycle only. No device, permission or identity access.
class PreviewIdentityFocusPort implements IdentityCapturePort {
  final _result = Completer<IdentityCaptureResult>();
  final _released = Completer<void>();
  bool _started = false;
  @override
  Future<String> prepare() async => 'mock-meta';
  @override
  Future<IdentityCaptureResult> capture(String certifyId) {
    _started = true;
    return _result.future;
  }

  @override
  Future<void> abort() async {
    if (_started && !_result.isCompleted) {
      _result.completeError(StateError('Mock cancellation'));
    }
    if (!_started && !_released.isCompleted) _released.complete();
  }

  Future<void> waitForRelease() => _released.future;
  void finish() {
    if (_started && !_result.isCompleted) {
      _result.complete(const IdentityCaptureResult(1000));
    }
    if (!_released.isCompleted) _released.complete();
  }
}
