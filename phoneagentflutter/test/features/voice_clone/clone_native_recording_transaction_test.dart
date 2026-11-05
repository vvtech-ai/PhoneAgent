import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_completion_controller.dart';
import 'clone_completion_fixtures.dart';

class _Prepared implements PreparedCloneRecordingSave {
  final download = Completer<void>();
  int commits = 0, cancels = 0;
  @override
  Future<void> commit() async {
    commits++;
    await download.future;
  }

  @override
  void cancel() {
    cancels++;
  }
}

void main() {
  test(
    'native prepare before confirm, return without waiting for recording',
    () async {
      final prepared = _Prepared();
      final port = CompletionPortFixture()
        ..pendingConfirm = Completer<CloneCandidate>();
      var prepares = 0;
      final controller = CloneCompletionController(
        candidate: completionCandidate(),
        port: port,
        grant: completionGrant(),
        isCurrent: () => true,
        saveRecording: (_) async => fail('legacy save used'),
        prepareRecording: (_) {
          prepares++;
          return prepared;
        },
      );
      final confirmation = controller.confirm(save: true);
      expect(prepares, 1);
      expect(prepared.commits, 0);
      port.pendingConfirm!.complete(port.result);
      await confirmation;
      expect(controller.state.phase, CloneCompletionPhase.confirmed);
      expect(controller.state.busy, isFalse);
      expect(prepared.commits, 1);
      controller.dispose();
      expect(prepared.cancels, 0);
      prepared.download.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'failed confirmation cancels pending recording and never commits',
    () async {
      final prepared = _Prepared();
      final port = CompletionPortFixture()..fail = true;
      final controller = CloneCompletionController(
        candidate: completionCandidate(),
        port: port,
        grant: completionGrant(),
        isCurrent: () => true,
        saveRecording: (_) async => fail('legacy save used'),
        prepareRecording: (_) => prepared,
      );
      await controller.confirm(save: true);
      expect(prepared.cancels, 1);
      expect(prepared.commits, 0);
      port.activated = true;
      await controller.synchronize();
      expect(prepared.commits, 0);
      controller.dispose();
    },
  );
  test(
    'confirmed notification closing route cannot cancel committed recording',
    () async {
      final prepared = _Prepared();
      var current = true;
      final controller = CloneCompletionController(
        candidate: completionCandidate(),
        port: CompletionPortFixture(),
        grant: completionGrant(),
        isCurrent: () => current,
        saveRecording: (_) async {},
        prepareRecording: (_) => prepared,
      );
      controller.addListener((value) {
        if (value.phase == CloneCompletionPhase.confirmed) current = false;
      }, fireImmediately: false);
      await controller.confirm(save: true);
      controller.dispose();
      expect(prepared.cancels, 0);
      expect(prepared.commits, 1);
      prepared.download.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );
  test('unselected recording never prepares', () async {
    final controller = CloneCompletionController(
      candidate: completionCandidate(),
      port: CompletionPortFixture(),
      grant: completionGrant(),
      isCurrent: () => true,
      saveRecording: (_) async => fail('save used'),
      prepareRecording: (_) => throw StateError('must not prepare'),
    );
    await controller.confirm(save: false);
    expect(controller.state.phase, CloneCompletionPhase.confirmed);
    controller.dispose();
  });
}
