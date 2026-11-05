import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';
import 'clone_completion_fixtures.dart';
import 'clone_flow_controller_test.dart' show flow, submit;

class _Processing implements CloneCandidateRepository {
  final result = Completer<CloneCandidate>();
  @override
  Future<CloneGeneratedCandidate> fromVerification(
    String modelId,
    String attemptId,
    String requestId,
  ) async => CloneGeneratedCandidate(
    const CloneCandidate(
      id: 'candidate-1',
      modelId: completionModel,
      status: CloneCandidateStatus.processing,
      source: CloneCandidateSource.verification,
      billing: CloneBillingStatus.reserved,
    ),
    recording: completionGrant(),
  );
  @override
  Future<CloneGeneratedCandidate> fromRecording(
    String modelId,
    CertifiedCloneRecording recording,
    String requestId,
  ) => throw UnimplementedError();
  @override
  Future<CloneCandidate> read(String modelId) => result.future;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform processing uses result card, disabled activation and blocked exit',
      (tester) async {
        final repo = _Processing();
        final controller = flow(PreviewCloneFlow(), candidates: repo);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: CloneFlowPage(controller: controller, preview: true),
          ),
        );
        await tester.pump();
        final pending = submit(controller);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('我的声音克隆'), findsOneWidget);
        expect(find.text('正在生成克隆音色'), findsOneWidget);
        expect(find.byKey(const Key('clone-save-recording')), findsOneWidget);
        expect(find.text('同步本次状态'), findsNothing);
        expect(controller.exitBlocked, isTrue);
        final preview = tester.widget<IconButton>(
          find.byKey(const Key('clone-preview')),
        );
        expect(preview.onPressed, isNull);
        expect(await controller.prepareExit(), isFalse);
        // A cancelled polling work must not leave the replacement flow busy.
        await controller.rerecord();
        expect(controller.busy, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        repo.result.complete(completionCandidate());
        await pending;
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
