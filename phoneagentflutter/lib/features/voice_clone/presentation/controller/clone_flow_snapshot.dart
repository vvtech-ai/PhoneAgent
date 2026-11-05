import 'clone_candidate_controller.dart';
import 'clone_completion_controller.dart';
import 'clone_flow_state.dart';

/// Keep the existing candidate usable until replacement creation succeeds.
class CloneFlowSnapshot {
  CloneFlowSnapshot(this.candidate, this.completion, this.state);
  final CloneCandidateController candidate;
  final CloneCompletionController? completion;
  final CloneFlowState state;
  void dispose() {
    candidate.dispose();
    completion?.dispose();
  }
}
