import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_enrollment_port.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_enrollment_controller.dart';

void main() {
  test(
    'recording result hides save, skips identity and confirms without save',
    () async {
      final port = _Port();
      final controller = CloneEnrollmentController(port, reuseOnRerecord: true);
      addTearDown(controller.dispose);
      await controller.openCandidate(CloneCreationStart.savedRecording);
      expect(controller.state.step, CloneStep.candidate);
      expect(controller.state.showSaveRecording, false);
      expect(controller.needsExitConfirmation, false);
      controller.saveRecording(true);
      expect(controller.state.saveRecording, false);
      await controller.confirm();
      expect(port.saved, false);
      expect(controller.state.step, CloneStep.confirmed);
    },
  );
  test(
    'expired recording returns consent and later auth can save new recording',
    () async {
      final port = _Port()..ready = false;
      final controller = CloneEnrollmentController(port, reuseOnRerecord: true);
      addTearDown(controller.dispose);
      await controller.openCandidate(CloneCreationStart.savedRecording);
      expect(controller.state.step, CloneStep.consent);
      expect(controller.state.error, contains('失效'));
      controller.agree(true);
      controller.next();
      await controller.submitIdentity('演练用户', '000000200001010005');
      expect(controller.state.showSaveRecording, true);
      expect(controller.needsExitConfirmation, true);
      controller.rerecord();
      expect(controller.state.step, CloneStep.consent);
      expect(port.starts, [CloneCreationStart.savedRecording]);
    },
  );
  test(
    'failed candidate retry reads existing; explicit rerecord generates new',
    () async {
      final port = _Port()..fail = true;
      final controller = CloneEnrollmentController(port, reuseOnRerecord: true);
      addTearDown(controller.dispose);
      await controller.openCandidate(CloneCreationStart.existingCandidate);
      expect(controller.state.step, CloneStep.candidateError);
      await controller.retryCandidate();
      expect(port.starts, [
        CloneCreationStart.existingCandidate,
        CloneCreationStart.existingCandidate,
      ]);
      port.fail = false;
      controller.rerecord();
      await Future<void>.delayed(Duration.zero);
      expect(port.starts.last, CloneCreationStart.savedRecording);
      expect(controller.state.step, CloneStep.candidate);
    },
  );
  test(
    'verification-sourced existing candidate rerecord uses full auth',
    () async {
      final controller = CloneEnrollmentController(_Port());
      addTearDown(controller.dispose);
      await controller.openCandidate(CloneCreationStart.existingCandidate);
      controller.rerecord();
      expect(controller.state.step, CloneStep.consent);
    },
  );
  test(
    'disposed pending start is ignored and duplicate start blocked',
    () async {
      final port = _Port()..pending = Completer<bool>();
      final controller = CloneEnrollmentController(port);
      final first = controller.openCandidate(CloneCreationStart.savedRecording);
      await controller.openCandidate(CloneCreationStart.savedRecording);
      expect(port.starts.length, 1);
      controller.dispose();
      port.pending!.complete(true);
      await first;
    },
  );
}

class _Port extends PreviewCloneEnrollmentPort
    implements CloneCandidateEntryPort {
  _Port() : super(ClonePreviewScenario.success, delay: Duration.zero);
  bool ready = true, fail = false;
  bool? saved;
  Completer<bool>? pending;
  final starts = <CloneCreationStart>[];
  @override
  Future<bool> openCandidate(CloneCreationStart start) async {
    starts.add(start);
    if (fail) throw StateError('candidate');
    return pending == null ? ready : pending!.future;
  }

  @override
  Future<void> confirm({required bool saveRecording}) async {
    saved = saveRecording;
  }
}
