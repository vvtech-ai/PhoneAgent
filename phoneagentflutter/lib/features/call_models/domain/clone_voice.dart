import 'call_models.dart';

bool supportsCloneVoice(String provider) =>
    const {
      'QWEN_OMNI_PLUS',
      'DOUBAO_SEEDUPLEX_3_0',
    }.contains(normalizeProvider(provider)) ||
    RegExp(r'^[1-9][0-9]*$').hasMatch(provider);

class CloneVoiceSnapshot {
  const CloneVoiceSnapshot({
    required this.modelId,
    required this.available,
    required this.currentStatus,
    required this.currentHasAsset,
    this.pricePoints,
    this.unavailableReason = '',
    this.candidateStatus = '',
    this.candidateBillingStatus = '',
  });
  final String modelId,
      currentStatus,
      candidateStatus,
      candidateBillingStatus,
      unavailableReason;
  final bool available, currentHasAsset;
  final int? pricePoints;
  bool get currentReady =>
      currentStatus.toUpperCase() == 'READY' && currentHasAsset;
  bool get candidateReady =>
      candidateStatus.toUpperCase() == 'READY' &&
      candidateBillingStatus.toUpperCase() == 'CHARGED';
  bool get canSelect =>
      supportsCloneVoice(modelId) && (currentReady || candidateReady);
  bool get hasProcessing =>
      candidateStatus.toUpperCase() == 'PROCESSING' ||
      currentStatus.toUpperCase() == 'PROCESSING';
}

abstract interface class CloneVoiceRepository {
  Future<CloneVoiceSnapshot> load(String provider);
  Future<CallVoiceCatalog> selectConfirmed(String provider);
  Future<void> confirmCandidate(String provider);
}

/// Separate capability so read-only/selection ports cannot accidentally delete.
abstract interface class CloneVoiceDeletionPort {
  Future<void> deleteConfirmed(String provider);
}
