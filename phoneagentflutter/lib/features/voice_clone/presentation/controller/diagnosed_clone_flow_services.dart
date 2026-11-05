import 'dart:typed_data';
import '../../../../core/diagnostics/clone_diagnostics.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../data/diagnosed_clone_verification.dart';
import '../../domain/clone_candidate.dart';
import '../../domain/clone_completion.dart';
import '../../domain/clone_preview_player.dart';
import 'clone_flow_services.dart';

CloneFlowServices diagnoseCloneFlowServices(
  CloneFlowServices s,
  CloneDiagnostics d, {
  int? pricePoints,
}) => CloneFlowServices(
  diagnostics: d,
  models: s.models,
  verification: DiagnosedCloneVerification(s.verification, d),
  candidates: DiagnosedCloneCandidates(s.candidates, d),
  completion: _Completion(s.completion, d),
  capture: () => DiagnosedIdentityCapture(s.capture(), d),
  player: _Player(s.player, d),
  recordings: CloneFlowRecordings(
    read: () => d.run(
      DiagnosticCloneStage.recordingRead,
      s.recordings.read,
      state: (v) => v == null ? 'missing' : 'present',
    ),
    save: (grant) => d.run(
      DiagnosticCloneStage.recordingSave,
      () => s.recordings.save(grant),
    ),
    clear: () => d.run(DiagnosticCloneStage.recordingClear, s.recordings.clear),
    prepareSave: s.recordings.prepareSave == null
        ? null
        : (grant) => d.sync(
            DiagnosticCloneStage.recordingPrepare,
            () => _Prepared(s.recordings.prepareSave!(grant), d),
          ),
  ),
  points: () => d.run(
    DiagnosticCloneStage.admission,
    s.points,
    state: (v) => pricePoints == null || pricePoints <= 0
        ? 'missing'
        : v < pricePoints
        ? 'rejected'
        : 'passed',
  ),
  verifiedName: () =>
      d.run(DiagnosticCloneStage.identityPrefill, s.verifiedName),
  identityPrefill: s.identityPrefill == null
      ? null
      : () => d.run(DiagnosticCloneStage.identityPrefill, s.identityPrefill!),
  resetIdentity: s.resetIdentity,
  captureSupported: s.captureSupported,
  onBilling: s.onBilling,
  isCurrent: s.isCurrent,
);

class _Completion implements CloneCompletionPort {
  _Completion(this.inner, this.log);
  final CloneCompletionPort inner;
  final CloneDiagnostics log;
  @override
  Future<CloneCandidate> confirm(CloneCandidate candidate) => log.run(
    DiagnosticCloneStage.confirmation,
    () => inner.confirm(candidate),
    state: (v) => v.status.name,
  );
  @override
  Future<bool> isActivated(CloneCandidate candidate) => log.run(
    DiagnosticCloneStage.activationRead,
    () => inner.isActivated(candidate),
    state: (v) => v ? 'active' : 'inactive',
  );
  @override
  Future<Uint8List> preview(String modelId, {bool current = false}) => log.run(
    DiagnosticCloneStage.previewDownload,
    () => inner.preview(modelId, current: current),
  );
  @override
  Future<void> restoreSystemVoice(String modelId) => log.run(
    DiagnosticCloneStage.restoreVoice,
    () => inner.restoreSystemVoice(modelId),
  );
}

class _Player implements ClonePreviewPlayer {
  _Player(this.inner, this.log);
  final ClonePreviewPlayer inner;
  final CloneDiagnostics log;
  @override
  Future<void> play(Uint8List bytes) =>
      log.run(DiagnosticCloneStage.previewPlayback, () => inner.play(bytes));
  @override
  Future<void> stop() => log.run(DiagnosticCloneStage.previewStop, inner.stop);
  @override
  Future<void> close() =>
      log.run(DiagnosticCloneStage.playerClose, inner.close);
}

class _Prepared implements PreparedCloneRecordingSave {
  _Prepared(this.inner, this.log);
  final PreparedCloneRecordingSave inner;
  final CloneDiagnostics log;
  Future<void>? _commit;
  @override
  Future<void> commit() =>
      _commit ??= log.run(DiagnosticCloneStage.recordingSave, inner.commit);
  @override
  void cancel() => log.sync(DiagnosticCloneStage.recordingPrepare, () {
    inner.cancel();
    log.event(
      DiagnosticCloneStage.recordingPrepare,
      DiagnosticResult.cancelled,
    );
  });
}
