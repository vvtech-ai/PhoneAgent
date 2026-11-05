import '../domain/clone_creation.dart';
import 'preview_clone_enrollment_port.dart';

enum CloneCreationScenario {
  reusable,
  absent,
  expired,
  existing,
  processing,
  failed,
  insufficient,
  loadFailure,
}

/// Isolated source for the shared entry. No real identity, recording or wallet.
class PreviewCloneCreationPort implements CloneCreationPort {
  PreviewCloneCreationPort(this.scenario);
  final CloneCreationScenario scenario;
  bool _loadFailed = false;
  @override
  Future<List<CloneCreationModel>> models() async {
    if (scenario == CloneCreationScenario.loadFailure && !_loadFailed) {
      _loadFailed = true;
      throw StateError('Synthetic load failure');
    }
    return [
      CloneCreationModel(
        cloneEntitled: true,
        pricePoints: 300,
        id: 'QWEN_OMNI_PLUS',
        name: 'QwenOmniPlus',
        currentReady: scenario == CloneCreationScenario.existing,
        hasCandidate:
            scenario == CloneCreationScenario.processing ||
            scenario == CloneCreationScenario.failed,
        candidateFromRecording: true,
      ),
      const CloneCreationModel(
        cloneEntitled: true,
        pricePoints: 300,
        id: 'DOUBAO_SEEDUPLEX_3_0',
        name: 'Seeduplex V3',
      ),
    ];
  }

  @override
  Future<int> availablePoints() async =>
      scenario == CloneCreationScenario.insufficient ? 299 : 900;
  @override
  Future<bool> hasValidRecording() async =>
      scenario != CloneCreationScenario.absent;
}

class PreviewCloneCreationEnrollmentPort extends PreviewCloneEnrollmentPort
    implements CloneCandidateEntryPort {
  PreviewCloneCreationEnrollmentPort(this.creationScenario, {super.delay})
    : super(ClonePreviewScenario.success);
  final CloneCreationScenario creationScenario;
  @override
  Future<bool> openCandidate(CloneCreationStart start) async {
    await Future<void>.delayed(delay);
    if (creationScenario == CloneCreationScenario.expired) return false;
    if (creationScenario == CloneCreationScenario.failed &&
        start == CloneCreationStart.existingCandidate) {
      throw StateError('Synthetic existing failed candidate');
    }
    return true;
  }
}
