import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_enrollment_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_presentation.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_state.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_verification_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';
import 'clone_flow_controller_test.dart' show flow, submit;

void main() {
  test(
    'a synchronized generation failure releases old flow before retry',
    () async {
      final ports = PreviewCloneFlow();
      final candidates = _ProcessingThenFailed(ports);
      final controller = flow(ports, candidates: candidates);
      addTearDown(controller.dispose);
      await submit(controller);
      await controller.synchronize();
      expect(controller.state.ui.step, CloneStep.identity);
      expect(controller.hasCandidateResult, isFalse);
      await controller.submitIdentity('演练', '000000200001010005');
      expect(candidates.fromVerified, 2);
      expect(controller.state.ui.step, CloneStep.candidate);
    },
  );
  for (final phase in [
    VerificationPhase.failed,
    VerificationPhase.rejected,
    VerificationPhase.cancelled,
  ]) {
    test('$phase returns to identity with failure and consent retained', () {
      final result = presentCloneVerification(
        CloneVerificationState(phase: phase, issue: VerificationIssue.capture),
        const CloneFlowState(ui: CloneEnrollmentState(agreed: true)),
      );
      expect(result.ui.step, CloneStep.identity);
      expect(result.ui.agreed, isTrue);
      expect(result.ui.error, isNotEmpty);
      expect(result.recovery, CloneFlowRecovery.none);
    });
  }
  test('unknown verification remains a read-only recovery', () {
    final result = presentCloneVerification(
      const CloneVerificationState(phase: VerificationPhase.needsSync),
      const CloneFlowState(),
    );
    expect(result.ui.step, isNot(CloneStep.identity));
    expect(result.recovery, CloneFlowRecovery.verification);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform failure retains masked identity and retries in place',
      (tester) async {
        final ports = PreviewCloneFlow()..capture.code = 1001;
        final controller = CloneFlowController(
          const CloneCreationLaunch(
            CloneCreationModel(
              id: PreviewCloneFlow.model,
              name: '合成模型',
              pricePoints: 300,
            ),
            CloneCreationStart.authentication,
          ),
          CloneFlowServices(
            verification: ports.verification,
            candidates: ports.candidates,
            completion: ports,
            capture: () => ports.capture,
            player: ports,
            recordings: CloneFlowRecordings(
              read: ports.readRecording,
              save: ports.save,
              clear: ports.clear,
            ),
            points: () async => 900,
            verifiedName: () async => '',
            isCurrent: () => ports.current,
          ),
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: CloneFlowPage(controller: controller),
          ),
        );
        controller.agree(true);
        await controller.next();
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '演练用户');
        await tester.enterText(
          find.byType(TextField).last,
          '000000200001010005',
        );
        await tester.ensureVisible(find.text('开始人脸跟读认证'));
        await tester.tap(find.text('开始人脸跟读认证'));
        await tester.pumpAndSettle();
        expect(find.text('1/3 填写信息'), findsOneWidget);
        expect(find.text('返回重新认证'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          '000***********0005',
        );
        await tester.ensureVisible(find.text('开始人脸跟读认证'));
        await tester.tap(find.text('开始人脸跟读认证'));
        await tester.pumpAndSettle();
        expect(ports.verification.initializes, 2);
        expect(ports.verification.lastIdentity!.number, '000000200001010005');
        expect(ports.candidates.fromVerified, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _ProcessingThenFailed extends PreviewFlowCandidates {
  _ProcessingThenFailed(super.owner);
  @override
  Future<CloneGeneratedCandidate> fromVerification(
    String modelId,
    String attemptId,
    String requestId,
  ) async {
    if (fromVerified == 0) {
      fromVerified++;
      return CloneGeneratedCandidate(
        PreviewCloneFlow.candidate(
          modelId: modelId,
          status: CloneCandidateStatus.processing,
        ),
      );
    }
    return super.fromVerification(modelId, attemptId, requestId);
  }

  @override
  Future<CloneCandidate> read(String modelId) async {
    if (reads++ == 0) throw StateError('temporary query failure');
    return CloneCandidate(
      id: 'mock-candidate',
      modelId: modelId,
      status: CloneCandidateStatus.failed,
      billing: CloneBillingStatus.released,
      source: CloneCandidateSource.verification,
      lastError: '音频过短，请重新录制',
    );
  }
}
