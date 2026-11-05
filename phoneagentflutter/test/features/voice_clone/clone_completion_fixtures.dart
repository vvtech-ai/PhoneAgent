import 'dart:async';
import 'dart:typed_data';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_completion.dart';

const completionModel = 'QWEN_OMNI_PLUS';
CloneCandidate completionCandidate({
  String id = 'candidate-1',
  String asset = 'synthetic-asset',
  CloneCandidateStatus status = CloneCandidateStatus.ready,
}) => CloneCandidate(
  id: id,
  modelId: completionModel,
  status: status,
  source: CloneCandidateSource.verification,
  billing: CloneBillingStatus.charged,
  providerAssetId: asset,
);
Map<String, dynamic> completionJson({String status = 'CONFIRMED'}) => {
  'candidateId': 'candidate-1',
  'modelId': completionModel,
  'providerAssetId': 'synthetic-asset',
  'status': status,
  'source': 'VERIFICATION',
  'billingStatus': 'CHARGED',
};
CloneRecordingGrant completionGrant() => CloneRecordingGrant(
  attemptId: 'attempt-1',
  grant: 'synthetic-grant',
  receipt: 'synthetic-receipt',
  audioSha256: 'a' * 64,
  personFingerprint: 'synthetic-person',
  scriptVersion: 'test',
  expiresAt: DateTime.utc(2030),
);

class CompletionPortFixture implements CloneCompletionPort {
  int confirms = 0, reads = 0;
  bool fail = false, activated = false;
  Completer<CloneCandidate>? pendingConfirm;
  Completer<bool>? pendingRead;
  CloneCandidate result = completionCandidate(
    status: CloneCandidateStatus.confirmed,
  );
  @override
  Future<CloneCandidate> confirm(CloneCandidate candidate) async {
    confirms++;
    if (fail) throw StateError('synthetic failure');
    return pendingConfirm == null ? result : pendingConfirm!.future;
  }

  @override
  Future<bool> isActivated(CloneCandidate candidate) async {
    reads++;
    return pendingRead == null ? activated : pendingRead!.future;
  }

  @override
  Future<void> restoreSystemVoice(String modelId) async {}
  @override
  Future<Uint8List> preview(String modelId, {bool current = false}) async =>
      Uint8List(1);
}
