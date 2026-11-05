import 'dart:typed_data';
import 'clone_candidate.dart';

/// The confirmation endpoint deletes the candidate after promoting its asset.
/// Reconciliation therefore checks the current asset, not a missing candidate.
abstract interface class CloneCompletionPort {
  Future<CloneCandidate> confirm(CloneCandidate candidate);
  Future<bool> isActivated(CloneCandidate candidate);
  Future<void> restoreSystemVoice(String modelId);
  Future<Uint8List> preview(String modelId, {bool current = false});
}
