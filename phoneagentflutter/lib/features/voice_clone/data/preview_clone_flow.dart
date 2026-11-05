import 'dart:async';
import 'dart:typed_data';
import '../domain/clone_candidate.dart';
import '../domain/clone_completion.dart';
import '../domain/clone_preview_player.dart';
import '../domain/clone_verification.dart';

enum CloneFlowScenario {
  success,
  verificationSync,
  generationUnknown,
  confirmationUnknown,
  saveFailure,
  expiredRecording,
}

/// Entirely synthetic ports: no AccountApi, channels, storage or real player.
class PreviewCloneFlow implements CloneCompletionPort, ClonePreviewPlayer {
  PreviewCloneFlow([this.scenario = CloneFlowScenario.success]);
  final CloneFlowScenario scenario;
  late final verification = PreviewFlowVerification(this);
  late final candidates = PreviewFlowCandidates(this);
  late final capture = PreviewFlowCapture();
  int confirms = 0, saves = 0, restores = 0, clears = 0, plays = 0;
  int points = 900;
  String verifiedName = '';
  bool current = true, hasRecording = true, replacement = false;
  bool activated = false, closed = false;
  Completer<void>? _playback;
  static const model = 'QWEN_OMNI_PLUS';
  static CloneCandidate candidate({
    String modelId = model,
    CloneCandidateSource source = CloneCandidateSource.verification,
    CloneCandidateStatus status = CloneCandidateStatus.ready,
  }) => CloneCandidate(
    id: 'mock-candidate',
    modelId: modelId,
    status: status,
    source: source,
    billing: CloneBillingStatus.charged,
    providerAssetId: 'mock-asset',
  );
  static final grant = CloneRecordingGrant(
    attemptId: 'mock-attempt',
    grant: 'mock-grant',
    receipt: 'mock-receipt',
    audioSha256: '0' * 64,
    personFingerprint: 'mock-person',
    scriptVersion: 'mock-v1',
    expiresAt: DateTime.utc(2099),
  );
  Future<CertifiedCloneRecording?> readRecording() async => !hasRecording
      ? null
      : CertifiedCloneRecording(
          audio: Uint8List.fromList([0]),
          audioSha256: '0' * 64,
          personFingerprint: 'mock-person',
          scriptVersion: 'mock-v1',
          receipt: 'mock-receipt',
        );
  Future<void> save(CloneRecordingGrant grant) async {
    saves++;
    if (scenario == CloneFlowScenario.saveFailure && saves == 1) {
      throw StateError('mock');
    }
  }

  Future<void> clear() async {
    clears++;
    hasRecording = false;
  }

  @override
  Future<CloneCandidate> confirm(CloneCandidate value) async {
    confirms++;
    activated = true;
    if (scenario == CloneFlowScenario.confirmationUnknown) {
      throw StateError('mock');
    }
    return candidate(
      modelId: value.modelId,
      source: value.source,
      status: CloneCandidateStatus.confirmed,
    );
  }

  @override
  Future<bool> isActivated(CloneCandidate candidate) async => activated;
  @override
  Future<void> restoreSystemVoice(String modelId) async {
    restores++;
  }

  @override
  Future<Uint8List> preview(String modelId, {bool current = false}) async =>
      Uint8List.fromList([0]);
  @override
  Future<void> play(Uint8List wav) async {
    plays++;
    final playback = Completer<void>();
    _playback = playback;
    await Future.any([
      playback.future,
      Future<void>.delayed(const Duration(seconds: 1)),
    ]);
    if (identical(playback, _playback)) _playback = null;
  }

  @override
  Future<void> stop() async {
    final playback = _playback;
    if (playback != null && !playback.isCompleted) playback.complete();
    _playback = null;
  }

  @override
  Future<void> close() async {
    closed = true;
    await stop();
  }
}

class PreviewFlowVerification implements CloneVerificationRepository {
  PreviewFlowVerification(this.flow);
  final PreviewCloneFlow flow;
  int initializes = 0, reads = 0, replacements = 0;
  VerificationIdentity? lastIdentity;
  @override
  Future<bool> replacementRequired(String identityNumber) async {
    replacements++;
    return flow.replacement;
  }

  @override
  Future<VerificationAttempt> initialize(
    VerificationIdentity identity,
    String metaInfo,
  ) async {
    initializes++;
    lastIdentity = identity;
    return const VerificationAttempt(
      id: 'mock-attempt',
      certifyId: 'mock-certify',
      script: '这是合成演练，不采集真实声音',
      expiresAt: '2099-01-01',
    );
  }

  @override
  Future<VerificationSnapshot> read(String attemptId) async {
    reads++;
    if (flow.scenario == CloneFlowScenario.verificationSync && reads == 1) {
      throw StateError('mock');
    }
    return VerificationSnapshot(
      attemptId,
      VerificationStatus.pass,
      '2099-01-01',
    );
  }

  @override
  Future<void> observe(
    String attemptId,
    VerificationObservation observation,
  ) async {}
}

class PreviewFlowCandidates implements CloneCandidateRepository {
  PreviewFlowCandidates(this.flow);
  final PreviewCloneFlow flow;
  int fromVerified = 0, fromSaved = 0, reads = 0;
  CloneCandidateSource source = CloneCandidateSource.verification;
  final requests = <String>[];
  @override
  Future<CloneGeneratedCandidate> fromVerification(
    String modelId,
    String attemptId,
    String requestId,
  ) async {
    fromVerified++;
    requests.add(requestId);
    source = CloneCandidateSource.verification;
    if (flow.scenario == CloneFlowScenario.generationUnknown) {
      throw StateError('mock');
    }
    return CloneGeneratedCandidate(
      PreviewCloneFlow.candidate(modelId: modelId),
      recording: PreviewCloneFlow.grant,
    );
  }

  @override
  Future<CloneGeneratedCandidate> fromRecording(
    String modelId,
    CertifiedCloneRecording recording,
    String requestId,
  ) async {
    fromSaved++;
    requests.add(requestId);
    source = CloneCandidateSource.localRecording;
    if (flow.scenario == CloneFlowScenario.expiredRecording) {
      throw CloneGenerationFailure.identityExpired;
    }
    return CloneGeneratedCandidate(
      PreviewCloneFlow.candidate(modelId: modelId, source: source),
    );
  }

  @override
  Future<CloneCandidate> read(String modelId) async {
    reads++;
    return PreviewCloneFlow.candidate(modelId: modelId, source: source);
  }
}

class PreviewFlowCapture implements IdentityCapturePort {
  int prepares = 0, captures = 0, aborts = 0;
  int code = 1000;
  @override
  Future<String> prepare() async {
    prepares++;
    return 'mock-meta';
  }

  @override
  Future<IdentityCaptureResult> capture(String certifyId) async {
    captures++;
    return IdentityCaptureResult(code);
  }

  @override
  Future<void> abort() async {
    aborts++;
  }
}
