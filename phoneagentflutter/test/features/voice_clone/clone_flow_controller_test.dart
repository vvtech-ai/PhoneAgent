import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_state.dart';

CloneFlowController flow(
  PreviewCloneFlow ports, {
  CloneCreationStart start = CloneCreationStart.authentication,
  bool supported = true,
  CloneCandidateRepository? candidates,
  Future<int> Function()? points,
  Future<List<CloneCreationModel>> Function()? models,
  void Function(CloneCandidate, bool)? onBilling,
}) => CloneFlowController(
  CloneCreationLaunch(
    const CloneCreationModel(
      cloneEntitled: true,
      pricePoints: 300,
      id: PreviewCloneFlow.model,
      name: 'Qwen',
    ),
    start,
  ),
  CloneFlowServices(
    verification: ports.verification,
    candidates: candidates ?? ports.candidates,
    completion: ports,
    capture: () => ports.capture,
    player: ports,
    recordings: CloneFlowRecordings(
      read: ports.readRecording,
      save: ports.save,
      clear: ports.clear,
    ),
    points: points ?? () async => ports.points,
    models: models,
    verifiedName: () async => ports.verifiedName,
    isCurrent: () => ports.current,
    captureSupported: supported,
    onBilling: onBilling,
  ),
);
Future<void> submit(CloneFlowController controller) async {
  controller.agree(true);
  await controller.next();
  await controller.submitIdentity('演练', '000000200001010005');
}

void main() {
  test(
    'cancelled replacement retains prior candidate and recording option',
    () async {
      final ports = PreviewCloneFlow();
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.state.ui.showSaveRecording, isTrue);
      await controller.rerecord();
      expect(controller.restorePreviousCandidate(), isTrue);
      expect(controller.state.ui.step, CloneStep.candidate);
      expect(controller.state.ui.showSaveRecording, isTrue);
      await controller.confirm();
      expect(ports.confirms, 1);
      expect(ports.saves, 1);
    },
  );
  test(
    'failed replacement can restore previous ready candidate without regeneration',
    () async {
      final ports = PreviewCloneFlow();
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      await controller.rerecord();
      expect(
        controller.restorePreviousCandidate(error: '声音克隆失败，请重新开始。'),
        isTrue,
      );
      expect(controller.state.ui.error, '声音克隆失败，请重新开始。');
      expect(ports.candidates.fromVerified, 1);
      expect(controller.state.ui.step, CloneStep.candidate);
    },
  );

  for (final detail in ['音频过短，请重新录制', 'HTTP 503']) {
    test('generation failure presents native feedback: $detail', () async {
      final ports = PreviewCloneFlow();
      final controller = flow(
        ports,
        candidates: _FailedCandidates(ports, detail),
      );
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.state.ui.step, CloneStep.identity);
      expect(
        controller.state.ui.error,
        detail == 'HTTP 503' ? '声音克隆服务暂时不可用，请稍后重试。' : detail,
      );
      expect(controller.state.canRerecord, isFalse);
      expect(ports.confirms, 0);
    });
  }

  for (final start in CloneCreationStart.values) {
    test(
      'ready exit restores once and warning follows recording grant $start',
      () async {
        final ports = PreviewCloneFlow();
        final controller = flow(ports, start: start);
        addTearDown(controller.dispose);
        if (start == CloneCreationStart.authentication) {
          await submit(controller);
          expect(controller.needsExitConfirmation, isTrue);
          controller.saveRecording(false);
          expect(controller.needsExitConfirmation, isFalse);
          controller.saveRecording(true);
          expect(controller.needsExitConfirmation, isTrue);
        } else {
          // Reuse fixture provides its certified recording; opening an existing
          // candidate provides a ready candidate without a new recording grant.
          await controller.start();
          expect(controller.needsExitConfirmation, isFalse);
        }
        expect(controller.state.ui.step, CloneStep.candidate);
        expect(await controller.prepareExit(), isTrue);
        expect(await controller.prepareExit(), isTrue);
        expect(ports.restores, 1);
        expect(ports.confirms, 0);
        expect(ports.saves, 0);
      },
    );
  }

  for (final scenario in [
    CloneFlowScenario.success,
    CloneFlowScenario.confirmationUnknown,
  ]) {
    test(
      'generation and confirmed server facts notify wallet for $scenario',
      () async {
        final ports = PreviewCloneFlow(scenario);
        final facts = <(CloneCandidate, bool)>[];
        final controller = flow(
          ports,
          onBilling: (candidate, confirmed) =>
              facts.add((candidate, confirmed)),
        );
        addTearDown(controller.dispose);
        await submit(controller);
        expect(facts.any((fact) => fact.$1.ready && !fact.$2), isTrue);
        await controller.confirm();
        if (scenario == CloneFlowScenario.confirmationUnknown) {
          expect(facts.any((fact) => fact.$2), isFalse);
          await controller.synchronize();
        }
        expect(facts.any((fact) => fact.$2), isTrue);
        expect(ports.confirms, 1);
        final previous = facts.length;
        ports.current = false;
        await controller.confirm();
        expect(facts, hasLength(previous));
      },
    );
  }
  test(
    'wallet observer failure cannot undo clone confirmation or repeat generation',
    () async {
      final ports = PreviewCloneFlow();
      final controller = flow(
        ports,
        onBilling: (_, __) => throw StateError('wallet'),
      );
      addTearDown(controller.dispose);
      await submit(controller);
      await controller.confirm();
      expect(controller.state.ui.step, CloneStep.confirmed);
      expect(ports.candidates.fromVerified, 1);
      expect(ports.confirms, 1);
    },
  );
  test(
    'fresh grant is available even when generation immediately returns ready',
    () async {
      final ports = PreviewCloneFlow();
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.state.ui.step, CloneStep.candidate);
      expect(controller.state.ui.showSaveRecording, isTrue);
      expect(ports.candidates.requests.single, 'mock-attempt');
      await controller.confirm();
      await controller.confirm();
      expect(controller.state.ui.step, CloneStep.confirmed);
      expect(ports.confirms, 1);
      expect(ports.saves, 1);
    },
  );
  test('consent is required and no native calls occur on opening', () async {
    final ports = PreviewCloneFlow();
    final controller = flow(ports);
    addTearDown(controller.dispose);
    await controller.start();
    await controller.next();
    await controller.submitIdentity('演练', '000000200001010005');
    expect(controller.state.ui.step, CloneStep.consent);
    expect(ports.capture.prepares, 0);
    expect(ports.verification.initializes, 0);
  });
  test('web unsupported rejects before replacement query or SDK', () async {
    final ports = PreviewCloneFlow();
    final controller = flow(ports, supported: false);
    addTearDown(controller.dispose);
    await submit(controller);
    expect(controller.state.ui.error, contains('不支持'));
    expect(ports.capture.prepares, 0);
    expect(ports.verification.replacements, 0);
  });
  test('fresh points admission prevents SDK/paid generation', () async {
    final ports = PreviewCloneFlow()..points = 299;
    final controller = flow(ports);
    addTearDown(controller.dispose);
    await submit(controller);
    expect(controller.state.ui.error, contains('积分不足'));
    expect(ports.capture.prepares, 0);
    expect(ports.candidates.fromVerified, 0);
  });
  test('verified name is locked to server prefill', () async {
    final ports = PreviewCloneFlow()..verifiedName = '已认证演练姓名';
    final controller = flow(ports);
    addTearDown(controller.dispose);
    await submit(controller);
    expect(ports.verification.lastIdentity!.name, '已认证演练姓名');
  });
  test(
    'replacement cancel makes no initialization; confirm passes explicit flag',
    () async {
      final ports = PreviewCloneFlow()..replacement = true;
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.state.ui.replacement, isTrue);
      controller.cancelReplacement();
      await controller.confirmReplacement();
      expect(ports.verification.initializes, 0);
      await controller.submitIdentity('演练', '000000200001010005');
      await controller.confirmReplacement();
      expect(ports.verification.lastIdentity!.replacementConfirmed, isTrue);
      expect(ports.candidates.fromVerified, 1);
    },
  );
  test(
    'verification unknown only reads existing attempt then generates once',
    () async {
      final ports = PreviewCloneFlow(CloneFlowScenario.verificationSync);
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.state.recovery, CloneFlowRecovery.verification);
      expect(ports.candidates.fromVerified, 0);
      await controller.synchronize();
      await controller.synchronize();
      expect(ports.verification.initializes, 1);
      expect(ports.capture.captures, 1);
      expect(ports.candidates.fromVerified, 1);
      expect(controller.state.ui.step, CloneStep.candidate);
    },
  );
  test(
    'unknown generation stays read-only and cannot return to reauthentication',
    () async {
      final ports = PreviewCloneFlow(CloneFlowScenario.generationUnknown);
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.state.recovery, CloneFlowRecovery.candidate);
      expect(controller.state.creationFailed, isFalse);
      expect(controller.state.ui.step, CloneStep.generating);
      await controller.synchronize();
      expect(ports.candidates.fromVerified, 1);
      expect(ports.candidates.reads, 1);
      expect(controller.state.ui.error, contains('勿重复认证'));
      expect(controller.state.ui.showSaveRecording, isFalse);
      expect(controller.state.ui.step, CloneStep.generating);
      expect(controller.state.recovery, CloneFlowRecovery.candidate);
      await controller.confirm();
      await controller.togglePreview();
      await controller.rerecord();
      expect(ports.confirms, 0);
      expect(ports.plays, 0);
      expect(ports.verification.initializes, 1);
    },
  );
  test(
    'confirmation unknown only checks activation, never resends confirmation',
    () async {
      final ports = PreviewCloneFlow(CloneFlowScenario.confirmationUnknown);
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      await controller.confirm();
      expect(controller.state.recovery, CloneFlowRecovery.confirmation);
      await controller.confirm();
      await controller.synchronize();
      expect(ports.confirms, 1);
      expect(ports.saves, 1);
      expect(controller.state.ui.step, CloneStep.confirmed);
    },
  );
  test('save failure keeps confirmation and retries only save', () async {
    final ports = PreviewCloneFlow(CloneFlowScenario.saveFailure);
    final controller = flow(ports);
    addTearDown(controller.dispose);
    await submit(controller);
    await controller.confirm();
    expect(controller.state.saveFailed, isTrue);
    expect(controller.state.ui.step, CloneStep.confirmed);
    await controller.retrySave();
    expect(ports.saves, 2);
    expect(ports.confirms, 1);
    expect(controller.state.saveFailed, isFalse);
  });
  test('unchecked save never persists recording', () async {
    final ports = PreviewCloneFlow();
    final controller = flow(ports);
    addTearDown(controller.dispose);
    await submit(controller);
    controller.saveRecording(false);
    await controller.confirm();
    expect(ports.saves, 0);
    expect(ports.confirms, 1);
  });
  test(
    'saved recording skips SDK, hides save and rerecord reuses with a new operation',
    () async {
      final ports = PreviewCloneFlow();
      final controller = flow(ports, start: CloneCreationStart.savedRecording);
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.state.ui.step, CloneStep.candidate);
      expect(controller.state.ui.showSaveRecording, isFalse);
      await Future.wait([controller.rerecord(), controller.rerecord()]);
      expect(ports.candidates.fromSaved, 2);
      expect(ports.capture.prepares, 0);
      expect(ports.candidates.requests.toSet().length, 2);
    },
  );
  test('expired recording cleared before returning to consent', () async {
    final ports = PreviewCloneFlow(CloneFlowScenario.expiredRecording);
    final controller = flow(ports, start: CloneCreationStart.savedRecording);
    addTearDown(controller.dispose);
    await controller.start();
    expect(ports.clears, 1);
    expect(controller.state.ui.step, CloneStep.consent);
    expect(controller.state.ui.error, contains('失效'));
    expect(ports.capture.prepares, 0);
  });
  test(
    'opening existing candidate performs no wallet or generation write',
    () async {
      final ports = PreviewCloneFlow()..points = 0;
      final controller = flow(
        ports,
        start: CloneCreationStart.existingCandidate,
        points: () => throw StateError('must not read'),
      );
      addTearDown(controller.dispose);
      await controller.start();
      await controller.start();
      expect(ports.candidates.reads, 1);
      expect(ports.candidates.fromVerified, 0);
      expect(controller.state.ui.step, CloneStep.candidate);
    },
  );
  test(
    'unconfirmed verification exit restores only once; confirmed exit does not',
    () async {
      final ports = PreviewCloneFlow();
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.needsExitConfirmation, isTrue);
      expect(await controller.prepareExit(), isTrue);
      expect(ports.restores, 1);
      await controller.confirm();
      expect(await controller.prepareExit(), isTrue);
      expect(ports.restores, 1);
    },
  );
  test(
    'account switch while admission pending prevents subsequent SDK/API work',
    () async {
      final ports = PreviewCloneFlow();
      final points = Completer<int>();
      final controller = flow(ports, points: () => points.future);
      addTearDown(controller.dispose);
      final pending = submit(controller);
      await Future<void>.delayed(Duration.zero);
      ports.current = false;
      points.complete(900);
      await pending;
      expect(ports.verification.replacements, 0);
      expect(ports.capture.prepares, 0);
    },
  );
  test(
    'disposing pending admission prevents late calls and closes player',
    () async {
      final ports = PreviewCloneFlow();
      final points = Completer<int>();
      final controller = flow(ports, points: () => points.future);
      final pending = submit(controller);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      points.complete(900);
      await pending;
      expect(ports.closed, isTrue);
      expect(ports.verification.initializes, 0);
    },
  );
  test(
    'SDK cancellation cannot generate and preserves identity consent for retry',
    () async {
      final ports = PreviewCloneFlow();
      ports.capture.code = 1003;
      final controller = flow(ports);
      addTearDown(controller.dispose);
      await submit(controller);
      expect(controller.state.recovery, CloneFlowRecovery.none);
      expect(ports.candidates.fromVerified, 0);
      controller.restartAuthentication();
      expect(controller.state.ui.step, CloneStep.identity);
      expect(controller.state.ui.agreed, isTrue);
    },
  );
}

class _FailedCandidates extends PreviewFlowCandidates {
  _FailedCandidates(super.owner, this.detail);
  final String detail;
  @override
  Future<CloneGeneratedCandidate> fromVerification(
    String modelId,
    String attemptId,
    String requestId,
  ) async => CloneGeneratedCandidate(
    CloneCandidate(
      id: 'synthetic-failure',
      modelId: modelId,
      status: CloneCandidateStatus.failed,
      source: CloneCandidateSource.verification,
      billing: CloneBillingStatus.released,
      lastError: detail,
    ),
  );
}
