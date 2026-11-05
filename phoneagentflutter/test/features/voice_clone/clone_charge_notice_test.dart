import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';
import 'clone_flow_controller_test.dart' show flow, submit;

const charged = CloneCandidate(
  id: '', // Native responses can omit candidateId; billing still has to be shown.
  modelId: PreviewCloneFlow.model,
  status: CloneCandidateStatus.ready,
  source: CloneCandidateSource.verification,
  billing: CloneBillingStatus.charged,
  chargedPoints: 200,
  remainingPoints: 700,
);

class ChargedCandidates extends PreviewFlowCandidates {
  ChargedCandidates(super.flow);
  @override
  Future<CloneGeneratedCandidate> fromVerification(
    String modelId,
    String attemptId,
    String requestId,
  ) async => const CloneGeneratedCandidate(charged);
  @override
  Future<CloneGeneratedCandidate> fromRecording(
    String modelId,
    CertifiedCloneRecording recording,
    String requestId,
  ) async => const CloneGeneratedCandidate(charged);
  @override
  Future<CloneCandidate> read(String modelId) async => charged;
}

void main() {
  test(
    'new generation emits actual charge, opening historical result does not',
    () async {
      for (final start in CloneCreationStart.values) {
        final ports = PreviewCloneFlow();
        final controller = flow(
          ports,
          start: start,
          candidates: ChargedCandidates(ports),
        );
        addTearDown(controller.dispose);
        await controller.start();
        if (start == CloneCreationStart.authentication) {
          await submit(controller);
        }
        expect(
          controller.state.chargeNotice,
          start == CloneCreationStart.existingCandidate
              ? ''
              : '本次扣除 ✦200 积分，剩余 ✦700 积分',
        );
      }
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform new generation shows charge toast only once', (
      tester,
    ) async {
      final ports = PreviewCloneFlow();
      final controller = flow(
        ports,
        start: CloneCreationStart.savedRecording,
        candidates: ChargedCandidates(ports),
      );
      addTearDown(controller.dispose);
      addTearDown(dismissNativeNotice);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: CloneFlowPage(controller: controller, preview: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('本次扣除 ✦200 积分，剩余 ✦700 积分'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await controller.rerecord();
      expect(controller.restorePreviousCandidate(), isTrue);
      controller.saveRecording(false);
      await tester.pumpAndSettle();
      expect(find.text('本次扣除 ✦200 积分，剩余 ✦700 积分'), findsNothing);
    });
  }
}
