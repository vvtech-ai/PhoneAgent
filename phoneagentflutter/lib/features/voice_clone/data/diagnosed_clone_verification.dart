import '../../../core/diagnostics/clone_diagnostics.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../domain/clone_sdk_diagnosis.dart';
import '../domain/clone_verification.dart';
import '../domain/clone_candidate.dart';

class DiagnosedCloneVerification implements CloneVerificationRepository {
  DiagnosedCloneVerification(this.inner, this.log);
  final CloneVerificationRepository inner;
  final CloneDiagnostics log;
  @override
  Future<bool> replacementRequired(String number) => log.run(
    DiagnosticCloneStage.replacementCheck,
    () => inner.replacementRequired(number),
    state: (v) => v ? 'required' : 'notRequired',
  );
  @override
  Future<VerificationAttempt> initialize(
    VerificationIdentity identity,
    String meta,
  ) => log.run(
    DiagnosticCloneStage.verificationInit,
    () => inner.initialize(identity, meta),
  );
  @override
  Future<VerificationSnapshot> read(String attempt) => log.run(
    DiagnosticCloneStage.verificationRead,
    () => inner.read(attempt),
    state: (v) => v.status.name,
  );
  @override
  Future<void> observe(String attempt, VerificationObservation value) =>
      log.run(
        DiagnosticCloneStage.observation,
        () => inner.observe(attempt, value),
      );
}

class DiagnosedIdentityCapture implements IdentityCapturePort {
  DiagnosedIdentityCapture(this.inner, this.log);
  final IdentityCapturePort inner;
  final CloneDiagnostics log;
  @override
  Future<String> prepare() =>
      log.run(DiagnosticCloneStage.sdkPrepare, inner.prepare);
  @override
  Future<IdentityCaptureResult> capture(String certifyId) =>
      log.run(DiagnosticCloneStage.sdkCapture, () async {
        final watch = Stopwatch()..start();
        final value = await inner.capture(certifyId);
        final diagnosis = CloneSdkDiagnosis.observation(value, watch.elapsed);
        log.event(
          DiagnosticCloneStage.sdkCapture,
          DiagnosticResult.received,
          sdkCode: diagnosis.sdkCode,
          sdkSubCode: diagnosis.sdkSubCode ?? '',
          state: value.code == 1003
              ? 'cancelled'
              : CloneSdkDiagnosis.requiresServerQuery(value.code)
              ? 'checking'
              : 'rejected',
        );
        return value;
      });
  @override
  Future<void> abort() => log.run(DiagnosticCloneStage.sdkAbort, inner.abort);
}

class DiagnosedCloneCandidates implements CloneCandidateRepository {
  DiagnosedCloneCandidates(this.inner, this.log);
  final CloneCandidateRepository inner;
  final CloneDiagnostics log;
  @override
  Future<CloneGeneratedCandidate> fromVerification(
    String model,
    String attempt,
    String request,
  ) => log.run(
    DiagnosticCloneStage.generationVerification,
    () => inner.fromVerification(model, attempt, request),
    state: (v) => v.candidate.status.name,
  );
  @override
  Future<CloneGeneratedCandidate> fromRecording(
    String model,
    CertifiedCloneRecording recording,
    String request,
  ) => log.run(
    DiagnosticCloneStage.generationRecording,
    () => inner.fromRecording(model, recording, request),
    state: (v) => v.candidate.status.name,
  );
  @override
  Future<CloneCandidate> read(String model) => log.run(
    DiagnosticCloneStage.candidateRead,
    () => inner.read(model),
    state: (v) => v.status.name,
  );
}
