import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_completion_controller.dart';
import 'clone_completion_fixtures.dart';

void main() {
  late CompletionPortFixture port;
  late CloneCompletionController controller;
  late bool current, failSave;
  late int saves;
  Completer<void>? savePending;
  setUp(() {
    port = CompletionPortFixture();
    current = true;
    failSave = false;
    saves = 0;
    savePending = null;
    controller = CloneCompletionController(
      candidate: completionCandidate(),
      port: port,
      grant: completionGrant(),
      isCurrent: () => current,
      saveRecording: (_) async {
        saves++;
        if (failSave) throw StateError('synthetic storage failure');
        await savePending?.future;
      },
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });

  test(
    'confirm then save once, repeated confirm/retry/sync are no-ops',
    () async {
      await controller.confirm(save: true);
      expect(controller.state.phase, CloneCompletionPhase.confirmed);
      expect(controller.state.recording, CloneRecordingSave.saved);
      expect(controller.canSave, false);
      await controller.confirm(save: true);
      await controller.retrySave();
      await controller.synchronize();
      expect([port.confirms, port.reads, saves], [1, 0, 1]);
    },
  );
  test('unselected saving never writes and discards grant', () async {
    await controller.confirm(save: false);
    expect(controller.state.phase, CloneCompletionPhase.confirmed);
    expect(saves, 0);
    expect(controller.canSave, false);
  });
  test('saved-recording origin with no new grant does not save', () async {
    controller.dispose();
    controller = CloneCompletionController(
      candidate: completionCandidate(),
      port: port,
      isCurrent: () => true,
      saveRecording: (_) async {
        saves++;
      },
    );
    await controller.confirm(save: true);
    expect(controller.state.phase, CloneCompletionPhase.confirmed);
    expect(saves, 0);
  });
  test('save failure keeps confirmation and only save is retried', () async {
    failSave = true;
    await controller.confirm(save: true);
    expect(controller.state.phase, CloneCompletionPhase.confirmed);
    expect(controller.state.recording, CloneRecordingSave.failed);
    await controller.confirm(save: true);
    failSave = false;
    await controller.retrySave();
    expect([port.confirms, saves], [1, 2]);
    expect(controller.state.recording, CloneRecordingSave.saved);
  });
  test(
    'unknown confirm outcome reads activation without replaying POST',
    () async {
      port.fail = true;
      await controller.confirm(save: true);
      await controller.confirm(save: true);
      expect(controller.state.phase, CloneCompletionPhase.needsSync);
      await controller.synchronize();
      expect(controller.state.phase, CloneCompletionPhase.needsSync);
      expect(saves, 0);
      port.activated = true;
      await controller.synchronize();
      expect(controller.state.phase, CloneCompletionPhase.confirmed);
      expect([port.confirms, port.reads, saves], [1, 2, 1]);
    },
  );
  test(
    'response belongs to a different candidate or asset stays uncertain',
    () async {
      port.result = completionCandidate(
        id: 'other',
        status: CloneCandidateStatus.confirmed,
      );
      await controller.confirm(save: true);
      expect(controller.state.phase, CloneCompletionPhase.needsSync);
      expect(saves, 0);
    },
  );
  test(
    'successful confirm endpoint response commits without extra status requirement',
    () async {
      port.result = completionCandidate();
      await controller.confirm(save: true);
      expect(controller.state.phase, CloneCompletionPhase.confirmed);
      expect(saves, 1);
    },
  );
  test('confirmation is single-flight', () async {
    port.pendingConfirm = Completer();
    final first = controller.confirm(save: false);
    await controller.confirm(save: true);
    expect(port.confirms, 1);
    expect(controller.state.busy, true);
    port.pendingConfirm!.complete(port.result);
    await first;
    expect(saves, 0);
  });
  test('synchronization and save retry are single-flight', () async {
    port.fail = true;
    await controller.confirm(save: true);
    port.pendingRead = Completer();
    final sync = controller.synchronize();
    await controller.synchronize();
    expect(port.reads, 1);
    failSave = true;
    port.pendingRead!.complete(true);
    await sync;
    failSave = false;
    savePending = Completer();
    final retry = controller.retrySave();
    await controller.retrySave();
    expect(saves, 2);
    savePending!.complete();
    await retry;
    expect(controller.state.recording, CloneRecordingSave.saved);
  });
  for (final dispose in [false, true]) {
    test(
      'late confirmation cannot save after ${dispose ? 'dispose' : 'account change'}',
      () async {
        port.pendingConfirm = Completer();
        final pending = controller.confirm(save: true);
        if (dispose) {
          controller.dispose();
        } else {
          current = false;
        }
        port.pendingConfirm!.complete(port.result);
        await pending;
        expect(saves, 0);
      },
    );
  }
  test('account change during synchronization prevents saving', () async {
    port.fail = true;
    await controller.confirm(save: true);
    port.pendingRead = Completer();
    final sync = controller.synchronize();
    current = false;
    port.pendingRead!.complete(true);
    await sync;
    expect(saves, 0);
  });
  test('late save completion does not update disposed controller', () async {
    savePending = Completer();
    final reachedSave = Completer<void>();
    final remove = controller.addListener((state) {
      if (state.recording == CloneRecordingSave.saving) reachedSave.complete();
    }, fireImmediately: false);
    final pending = controller.confirm(save: true);
    await reachedSave.future;
    remove();
    controller.dispose();
    savePending!.complete();
    await pending;
    expect(saves, 1);
  });
  test(
    'missing asset does not block native model-scoped confirmation',
    () async {
      controller.dispose();
      controller = CloneCompletionController(
        candidate: completionCandidate(asset: ''),
        port: port,
        isCurrent: () => true,
        saveRecording: (_) async {},
      );
      await controller.confirm(save: true);
      await controller.synchronize();
      expect([port.confirms, port.reads], [1, 0]);
    },
  );
  test('state notification closing route cannot dispatch confirmation', () async {
    controller.addListener((state) {
      if (state.phase == CloneCompletionPhase.confirming) {
        // Riverpod invalidates ownership before deferred route/provider disposal.
        // Mutating StateNotifier's listener list during its own notification is unsupported.
        current = false;
        scheduleMicrotask(controller.dispose);
      }
    }, fireImmediately: false);
    await controller.confirm(save: true);
    expect([port.confirms, saves], [0, 0]);
  });
  test(
    'state notification changing account cannot dispatch recording save',
    () async {
      final remove = controller.addListener((state) {
        if (state.recording == CloneRecordingSave.saving) current = false;
      }, fireImmediately: false);
      await controller.confirm(save: true);
      remove();
      expect([port.confirms, saves], [1, 0]);
    },
  );
}
