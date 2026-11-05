import '../domain/clone_enrollment.dart';

enum ClonePreviewScenario {
  success,
  replacement,
  denied,
  verificationFailure,
  generationFailure,
  previewFailure,
  confirmationFailure,
}

/// No network, account provider, storage, camera, microphone or real audio.
class PreviewCloneEnrollmentPort implements CloneEnrollmentPort {
  PreviewCloneEnrollmentPort(
    this.scenario, {
    this.delay = const Duration(milliseconds: 600),
  });
  final ClonePreviewScenario scenario;
  final Duration delay;
  bool _closed = false, _failed = false;
  Future<void> _step(ClonePreviewScenario? failure) async {
    await Future<void>.delayed(delay);
    if (_closed) throw StateError('Closed');
    if (!_failed && failure == scenario) {
      _failed = true;
      throw StateError('Synthetic failure');
    }
  }

  @override
  Future<bool> replacementRequired(String identityNumber) async =>
      scenario == ClonePreviewScenario.replacement;
  @override
  Future<CloneVerification> initialize(
    String name,
    String identityNumber,
    bool replacementConfirmed,
  ) async {
    await _step(null);
    return const CloneVerification('synthetic', '这是一段仅用于界面演练的合成跟读文案，不会采集声音。');
  }

  @override
  Future<void> collect(CloneVerification verification) =>
      _step(ClonePreviewScenario.denied);
  @override
  Future<void> verify(CloneVerification verification) =>
      _step(ClonePreviewScenario.verificationFailure);
  @override
  Future<void> generate(CloneVerification verification) =>
      _step(ClonePreviewScenario.generationFailure);
  @override
  Future<void> preview() => _step(ClonePreviewScenario.previewFailure);
  @override
  void stopPreview() {}
  @override
  Future<void> confirm({required bool saveRecording}) =>
      _step(ClonePreviewScenario.confirmationFailure);
  @override
  void close() {
    _closed = true;
  }
}
