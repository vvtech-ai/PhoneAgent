import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/clone_candidate.dart';
import '../../domain/clone_completion.dart';

enum CloneCompletionPhase { ready, confirming, needsSync, confirmed }

enum CloneRecordingSave { notRequested, saving, saved, failed }

class CloneCompletionState {
  const CloneCompletionState({
    this.phase = CloneCompletionPhase.ready,
    this.recording = CloneRecordingSave.notRequested,
    this.synchronizing = false,
  });
  final CloneCompletionPhase phase;
  final CloneRecordingSave recording;
  final bool synchronizing;
  bool get busy =>
      phase == CloneCompletionPhase.confirming ||
      recording == CloneRecordingSave.saving ||
      synchronizing;
}

/// One candidate, one confirmation write. Saving cannot undo confirmed state.
class CloneCompletionController extends StateNotifier<CloneCompletionState> {
  CloneCompletionController({
    required this.candidate,
    required this.port,
    required this.saveRecording,
    required this.isCurrent,
    CloneRecordingGrant? grant,
    this.prepareRecording,
  }) : _grant = grant,
       super(const CloneCompletionState());
  final CloneCandidate candidate;
  final CloneCompletionPort port;
  final Future<void> Function(CloneRecordingGrant) saveRecording;
  final bool Function() isCurrent;
  CloneRecordingGrant? _grant;
  final PreparedCloneRecordingSave Function(CloneRecordingGrant)?
  prepareRecording;
  PreparedCloneRecordingSave? _prepared;
  bool _saveRequested = false;
  bool get _current => mounted && isCurrent();
  bool get canSave => _grant != null;

  Future<void> confirm({required bool save}) async {
    if (!_current ||
        state.phase != CloneCompletionPhase.ready ||
        !candidate.ready) {
      return;
    }
    _saveRequested = save && _grant != null;
    state = const CloneCompletionState(phase: CloneCompletionPhase.confirming);
    if (!_current) return;
    try {
      if (_saveRequested && prepareRecording != null) {
        try {
          _prepared = prepareRecording!(_grant!);
        } catch (_) {
          // Optional recording preparation cannot prevent voice activation.
          _saveRequested = false;
        }
      }
      final result = await port.confirm(candidate);
      if (!_current) return;
      if (result.modelId != candidate.modelId ||
          (result.id.isNotEmpty &&
              candidate.id.isNotEmpty &&
              result.id != candidate.id)) {
        throw const FormatException('Confirmation ownership mismatch');
      }
    } catch (_) {
      _prepared?.cancel();
      _prepared = null;
      if (prepareRecording != null) _saveRequested = false;
      if (_current) {
        state = const CloneCompletionState(
          phase: CloneCompletionPhase.needsSync,
        );
      }
      return;
    }
    await _confirmed();
  }

  Future<void> synchronize() async {
    if (!_current ||
        state.busy ||
        state.phase != CloneCompletionPhase.needsSync) {
      return;
    }
    state = const CloneCompletionState(
      phase: CloneCompletionPhase.needsSync,
      synchronizing: true,
    );
    if (!_current) return;
    try {
      final activated = await port.isActivated(candidate);
      if (!_current) return;
      if (activated) {
        await _confirmed();
        return;
      }
    } catch (_) {
      /* Unknown is not a reason to send confirmation again. */
    }
    if (_current) {
      state = const CloneCompletionState(phase: CloneCompletionPhase.needsSync);
    }
  }

  Future<void> _confirmed() async {
    if (!_current) return;
    final prepared = _prepared;
    _prepared = null;
    if (prepared != null) _grant = null;
    state = const CloneCompletionState(phase: CloneCompletionPhase.confirmed);
    if (prepared != null) {
      // Account-bound repository outlives this route; successful confirmation
      // closes immediately, while optional save completes independently.
      unawaited(prepared.commit().catchError((Object _) {}));
    } else if (_saveRequested) {
      await _save();
    } else {
      _grant = null;
    }
  }

  Future<void> retrySave() async {
    if (!_current ||
        state.phase != CloneCompletionPhase.confirmed ||
        state.recording != CloneRecordingSave.failed) {
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    final material = _grant;
    if (!_current || material == null) return;
    state = const CloneCompletionState(
      phase: CloneCompletionPhase.confirmed,
      recording: CloneRecordingSave.saving,
    );
    if (!_current) return;
    try {
      await saveRecording(material);
      if (!_current) return;
      _grant = null;
      state = const CloneCompletionState(
        phase: CloneCompletionPhase.confirmed,
        recording: CloneRecordingSave.saved,
      );
    } catch (_) {
      if (_current) {
        state = const CloneCompletionState(
          phase: CloneCompletionPhase.confirmed,
          recording: CloneRecordingSave.failed,
        );
      }
    }
  }

  @override
  void dispose() {
    _grant = null;
    _prepared?.cancel();
    _prepared = null;
    super.dispose();
  }
}
