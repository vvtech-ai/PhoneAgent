import '../../domain/clone_creation.dart';
import '../../../../core/diagnostics/clone_diagnostics.dart';
import '../../domain/clone_candidate.dart';
import '../../domain/clone_completion.dart';
import '../../domain/clone_preview_player.dart';
import '../../domain/clone_verification.dart';

/// Route-scoped ports. The page never sees the account API or native channels.
class CloneFlowServices {
  const CloneFlowServices({
    required this.verification,
    required this.candidates,
    required this.completion,
    required this.capture,
    required this.player,
    required this.recordings,
    required this.points,
    required this.verifiedName,
    required this.isCurrent,
    this.identityPrefill,
    this.resetIdentity,
    this.models,
    this.diagnostics,
    this.captureSupported = true,
    this.onBilling,
  });
  final Future<List<CloneCreationModel>> Function()? models;
  final CloneDiagnostics? diagnostics;
  final CloneVerificationRepository verification;
  final CloneCandidateRepository candidates;
  final CloneCompletionPort completion;
  final IdentityCapturePort Function() capture;
  final ClonePreviewPlayer player;
  final CloneFlowRecordings recordings;
  final Future<int> Function() points;
  final Future<String> Function() verifiedName;
  final Future<CloneIdentityPrefill> Function()? identityPrefill;

  /// False means deletion succeeded but local cleanup needs an explicit retry.
  final Future<bool> Function()? resetIdentity;
  final bool Function() isCurrent;
  final bool captureSupported;
  final void Function(CloneCandidate candidate, bool confirmed)? onBilling;
}

class CloneFlowRecordings {
  const CloneFlowRecordings({
    required this.read,
    required this.save,
    required this.clear,
    this.prepareSave,
  });
  final Future<CertifiedCloneRecording?> Function() read;
  final Future<void> Function(CloneRecordingGrant) save;
  final Future<void> Function() clear;
  final PreparedCloneRecordingSave Function(CloneRecordingGrant)? prepareSave;
}

/// One identity read provides both editable prefill and authoritative lock.
class CloneIdentityPrefill {
  const CloneIdentityPrefill({
    required this.name,
    required this.verified,
    this.certNoMasked = '',
  });
  final String name, certNoMasked;
  final bool verified;
}
