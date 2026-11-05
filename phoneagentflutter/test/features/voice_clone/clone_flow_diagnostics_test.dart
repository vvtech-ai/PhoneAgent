import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/clone_diagnostics.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/voice_clone/data/device_identity_capture_port.dart';
import 'package:phone_agent/features/voice_clone/data/diagnosed_clone_verification.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/diagnosed_clone_flow_services.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_verification_controller.dart';

CloneFlowServices services(PreviewCloneFlow p, CloneDiagnostics log) =>
    diagnoseCloneFlowServices(
      CloneFlowServices(
        verification: p.verification,
        candidates: p.candidates,
        completion: p,
        capture: () => p.capture,
        player: p,
        recordings: CloneFlowRecordings(
          read: p.readRecording,
          save: p.save,
          clear: p.clear,
        ),
        points: () async => p.points,
        verifiedName: () async => p.verifiedName,
        isCurrent: () => p.current,
      ),
      log,
    );
CloneFlowController controller(CloneFlowServices s) => CloneFlowController(
  const CloneCreationLaunch(
    CloneCreationModel(
      cloneEntitled: true,
      pricePoints: 300,
      id: PreviewCloneFlow.model,
      name: 'Synthetic',
    ),
    CloneCreationStart.authentication,
  ),
  s,
);
Future<void> submit(CloneFlowController c) async {
  c.agree(true);
  await c.next();
  await c.submitIdentity('演练', '000000200001010005');
}

class _ProcessingVerification extends PreviewFlowVerification {
  _ProcessingVerification(super.flow);
  @override
  Future<VerificationSnapshot> read(String attemptId) async {
    reads++;
    return VerificationSnapshot(
      attemptId,
      VerificationStatus.processing,
      '2099-01-01',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'poll exhaustion records limit and never creates another attempt',
    () async {
      final events = <DiagnosticEvent>[];
      final p = PreviewCloneFlow();
      final repo = _ProcessingVerification(p);
      final log = CloneDiagnostics(events.add);
      final c = CloneVerificationController(
        repository: DiagnosedCloneVerification(repo, log),
        capture: DiagnosedIdentityCapture(p.capture, log),
        isCurrent: () => true,
        diagnostics: log,
        maxPolls: 2,
        interval: Duration.zero,
      );
      addTearDown(c.dispose);
      await c.start(
        const VerificationIdentity(
          name: 'Synthetic',
          number: '000000200001010005',
        ),
      );
      expect(repo.initializes, 1);
      expect(repo.reads, 2);
      expect(c.state.issue, VerificationIssue.pollLimit);
      expect(events.any((v) => v.cloneFlow!.pollCount == 2), true);
      expect(events.any((v) => v.cloneFlow!.issue == 'pollLimit'), true);
    },
  );
  test(
    'SDK cancellation is distinguished and does not query certification',
    () async {
      final events = <DiagnosticEvent>[];
      final p = PreviewCloneFlow();
      p.capture.code = 1003;
      final log = CloneDiagnostics(events.add);
      final c = CloneVerificationController(
        repository: DiagnosedCloneVerification(p.verification, log),
        capture: DiagnosedIdentityCapture(p.capture, log),
        isCurrent: () => true,
        diagnostics: log,
      );
      addTearDown(c.dispose);
      await c.start(
        const VerificationIdentity(
          name: 'Synthetic',
          number: '000000200001010005',
        ),
      );
      expect(c.state.phase, VerificationPhase.cancelled);
      expect(p.verification.reads, 0);
      expect(
        events.any(
          (v) =>
              v.cloneFlow!.sdkCode == 1003 && v.cloneFlow!.state == 'cancelled',
        ),
        true,
      );
    },
  );
  test(
    'prepared save reports commit failure without retrying confirmation',
    () async {
      final events = <DiagnosticEvent>[];
      final log = CloneDiagnostics(events.add);
      final p = PreviewCloneFlow();
      final base = services(p, log);
      final inner = _FailingPrepared();
      final wrapped = diagnoseCloneFlowServices(
        CloneFlowServices(
          verification: base.verification,
          candidates: base.candidates,
          completion: base.completion,
          capture: base.capture,
          player: base.player,
          recordings: CloneFlowRecordings(
            read: base.recordings.read,
            save: base.recordings.save,
            clear: base.recordings.clear,
            prepareSave: (_) => inner,
          ),
          points: base.points,
          verifiedName: base.verifiedName,
          isCurrent: base.isCurrent,
        ),
        log,
      );
      final prepared = wrapped.recordings.prepareSave!(PreviewCloneFlow.grant);
      await expectLater(prepared.commit(), throwsStateError);
      await expectLater(prepared.commit(), throwsStateError);
      expect(inner.commits, 1);
      expect(
        events.any(
          (v) =>
              v.cloneFlow!.stage == DiagnosticCloneStage.recordingSave &&
              v.result == DiagnosticResult.failed,
        ),
        true,
      );
      expect(p.confirms, 0);
    },
  );

  test(
    'complete flow logs stages with same ID and preserves one init/generation/confirmation',
    () async {
      final events = <DiagnosticEvent>[];
      final p = PreviewCloneFlow();
      final log = CloneDiagnostics(events.add, platform: 'android');
      final c = controller(services(p, log));
      await submit(c);
      await c.togglePreview();
      await c.confirm();
      c.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(p.verification.initializes, 1);
      expect(p.candidates.fromVerified, 1);
      expect(p.confirms, 1);
      expect(p.saves, 1);
      final stages = events.map((v) => v.cloneFlow!.stage).toSet();
      expect(
        stages,
        containsAll([
          DiagnosticCloneStage.identityPrefill,
          DiagnosticCloneStage.admission,
          DiagnosticCloneStage.replacementCheck,
          DiagnosticCloneStage.sdkPrepare,
          DiagnosticCloneStage.verificationInit,
          DiagnosticCloneStage.sdkCapture,
          DiagnosticCloneStage.verificationRead,
          DiagnosticCloneStage.verificationState,
          DiagnosticCloneStage.observation,
          DiagnosticCloneStage.generationVerification,
          DiagnosticCloneStage.previewDownload,
          DiagnosticCloneStage.previewPlayback,
          DiagnosticCloneStage.confirmation,
          DiagnosticCloneStage.recordingSave,
          DiagnosticCloneStage.sdkAbort,
        ]),
      );
      expect(events.every((v) => v.sessionId == log.sessionId), true);
      final json = jsonEncode(events.map((v) => v.toJson()).toList());
      for (final value in [
        'mock-certify',
        'mock-receipt',
        'mock-person',
        'mock-asset',
        '演练',
        '000000200001010005',
      ]) {
        expect(json, isNot(contains(value)));
      }
    },
  );
  test(
    'confirmation unknown logs failure; synchronization reads, never reconfirms',
    () async {
      final events = <DiagnosticEvent>[];
      final p = PreviewCloneFlow(CloneFlowScenario.confirmationUnknown);
      final c = controller(services(p, CloneDiagnostics(events.add)));
      addTearDown(c.dispose);
      await submit(c);
      await c.confirm();
      await c.synchronize();
      expect(p.confirms, 1);
      expect(
        events.any(
          (v) =>
              v.cloneFlow!.stage == DiagnosticCloneStage.confirmation &&
              v.result == DiagnosticResult.failed,
        ),
        true,
      );
      expect(
        events.any(
          (v) => v.cloneFlow!.stage == DiagnosticCloneStage.activationRead,
        ),
        true,
      );
    },
  );
  test(
    'optional recording failure remains separate from activated voice',
    () async {
      final events = <DiagnosticEvent>[];
      final p = PreviewCloneFlow(CloneFlowScenario.saveFailure);
      final c = controller(services(p, CloneDiagnostics(events.add)));
      addTearDown(c.dispose);
      await submit(c);
      await c.confirm();
      expect(p.activated, true);
      expect(p.confirms, 1);
      expect(
        events.any(
          (v) =>
              v.cloneFlow!.stage == DiagnosticCloneStage.recordingSave &&
              v.result == DiagnosticResult.failed,
        ),
        true,
      );
    },
  );
  test('sink exceptions cannot change successful flow or add calls', () async {
    final p = PreviewCloneFlow();
    final c = controller(
      services(p, CloneDiagnostics((_) => throw StateError('sink'))),
    );
    addTearDown(c.dispose);
    await submit(c);
    await c.confirm();
    expect(p.confirms, 1);
    expect(p.verification.initializes, 1);
  });
  test(
    'SDK channel exception has safe stage and code classification, no raw details',
    () async {
      final events = <DiagnosticEvent>[];
      const channel = MethodChannel('phone_agent/identity_capture');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'capture_busy',
          message: 'secret-sdk-message',
          details: 'secret-device-token',
        );
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final log = CloneDiagnostics(events.add, platform: 'iOS');
      final device = DeviceIdentityCapturePort(
        platform: TargetPlatform.iOS,
        web: false,
        diagnostics: log,
      );
      final capture = DiagnosedIdentityCapture(device, log);
      await expectLater(
        capture.prepare(),
        throwsA(IdentityCaptureFailure.busy),
      );
      expect(
        events.any((v) => v.cloneFlow!.reason == DiagnosticCloneReason.busy),
        true,
      );
      expect(
        jsonEncode(events.map((v) => v.toJson()).toList()),
        isNot(contains('secret-')),
      );
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      await device.abort();
    },
  );
  test(
    'poll read failure has sequence and final issue without another initialization',
    () async {
      final events = <DiagnosticEvent>[];
      final p = PreviewCloneFlow(CloneFlowScenario.verificationSync);
      final log = CloneDiagnostics(events.add);
      final c = CloneVerificationController(
        repository: DiagnosedCloneVerification(p.verification, log),
        capture: DiagnosedIdentityCapture(p.capture, log),
        isCurrent: () => true,
        diagnostics: log,
        maxPolls: 1,
        interval: Duration.zero,
      );
      addTearDown(c.dispose);
      await c.start(
        const VerificationIdentity(
          name: 'Synthetic',
          number: '000000200001010005',
        ),
      );
      expect(p.verification.initializes, 1);
      expect(events.any((v) => v.cloneFlow!.pollCount == 1), true);
      // Preview's first failed read is explicit and leaves a read-only recovery.
      expect(c.state.phase, VerificationPhase.needsSync);
      expect(
        events
            .lastWhere(
              (v) =>
                  v.cloneFlow!.stage == DiagnosticCloneStage.verificationState,
            )
            .cloneFlow!
            .issue,
        'request',
      );
    },
  );
}

class _FailingPrepared implements PreparedCloneRecordingSave {
  int commits = 0;
  @override
  Future<void> commit() async {
    commits++;
    throw StateError('secret-storage-error');
  }

  @override
  void cancel() {}
}
