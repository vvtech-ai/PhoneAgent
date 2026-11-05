import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_admission.dart';
import 'package:phone_agent/features/calls/domain/call_launch_coordinator.dart';
import '../../support/call_admission_fixture.dart';

void main() {
  testWidgets(
    'presenting a live card waits indefinitely for explicit confirmation',
    (tester) async {
      final f = AdmissionFixture();
      var submits = 0;
      final c = CallLaunchCoordinator(
        admission: f.service,
        submit: (_) async {
          submits++;
        },
        onState: (_) {},
      );
      addTearDown(c.close);
      expect(c.present(callRequest()), isTrue);
      await tester.pump(const Duration(seconds: 10));
      expect(submits, 0);
      expect(c.state.phase, CallLaunchPhase.awaitingConfirmation);
      expect(c.present(callRequest()), isFalse);
      expect(c.confirmCurrent('确认拨打'), isFalse);
      c.reportPresented(callRequest().identity, callRequest().specSignature);
      expect(c.confirmCurrent('确认拨打'), isTrue);
      expect(c.confirmCurrent('确认拨打'), isFalse);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(submits, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(submits, 1);
      expect(c.confirmationText, '确认拨打');
    },
  );
  testWidgets('explicit confirmation preparation remains cancellable', (
    tester,
  ) async {
    final f = AdmissionFixture();
    var submits = 0;
    final c = CallLaunchCoordinator(
      admission: f.service,
      submit: (_) async {
        submits++;
      },
      onState: (_) {},
    );
    addTearDown(c.close);
    c.present(callRequest());
    c.reportPresented(callRequest().identity, callRequest().specSignature);
    c.confirmCurrent('确认拨打');
    c.cancelPending();
    await tester.pump(const Duration(seconds: 2));
    expect(submits, 0);
    expect(c.confirmCurrent('确认拨打'), isFalse);
  });
  testWidgets(
    'live confirmation waits 1500ms and duplicate tool submits once',
    (tester) async {
      final f = AdmissionFixture();
      var submits = 0;
      final c = CallLaunchCoordinator(
        admission: f.service,
        submit: (_) async {
          submits++;
        },
        onState: (_) {},
      );
      addTearDown(c.close);
      expect(c.schedule(callRequest()), isTrue);
      expect(c.schedule(callRequest()), isFalse);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(submits, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(submits, 1);
      expect(c.state.phase, CallLaunchPhase.submitted);
      expect(c.schedule(callRequest()), isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(submits, 1);
    },
  );
  testWidgets(
    'new input or restore cancels pending, late duplicate cannot relaunch',
    (tester) async {
      final f = AdmissionFixture();
      var submits = 0;
      final c = CallLaunchCoordinator(
        admission: f.service,
        submit: (_) async {
          submits++;
        },
        onState: (_) {},
      );
      addTearDown(c.close);
      c.schedule(callRequest());
      c.cancelPending();
      expect(c.schedule(callRequest()), isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(submits, 0);
      expect(c.state.phase, CallLaunchPhase.idle);
    },
  );
  testWidgets('new request replaces delay; close cancels it permanently', (
    tester,
  ) async {
    final f = AdmissionFixture();
    final submitted = <String>[];
    final c = CallLaunchCoordinator(
      admission: f.service,
      submit: (r) async {
        submitted.add(r.toolId);
      },
      onState: (_) {},
    );
    c.schedule(callRequest());
    await tester.pump(const Duration(seconds: 1));
    c.schedule(callRequest(tool: 'next'));
    await tester.pump(const Duration(seconds: 1));
    expect(submitted, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(submitted, ['next']);
    c.schedule(callRequest(tool: 'last'));
    c.close();
    await tester.pump(const Duration(seconds: 2));
    expect(submitted, ['next']);
    expect(c.schedule(callRequest(tool: 'closed')), isFalse);
  });
  testWidgets(
    'first insufficient publishes before commit, repeated shows dialog decision without another POST',
    (tester) async {
      final f = AdmissionFixture()
        ..balance = 0
        ..refreshed = 0;
      var submits = 0, commitsWhenBlocked = -1;
      final c = CallLaunchCoordinator(
        admission: f.service,
        submit: (_) async {
          submits++;
        },
        onState: (s) {
          if (s.phase == CallLaunchPhase.blocked) {
            commitsWhenBlocked = f.commits;
          }
        },
      );
      addTearDown(c.close);
      c.schedule(callRequest());
      await tester.pump(const Duration(milliseconds: 1500));
      expect(commitsWhenBlocked, 0);
      expect(f.commits, 1);
      expect(c.state.decision!.kind, CallAdmissionKind.firstInsufficient);
      c.schedule(
        callRequest(tool: 'next', ordinal: 2),
        priorRequests: [callRequest()],
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(c.state.decision!.kind, CallAdmissionKind.repeatedInsufficient);
      expect(f.refreshes, 2);
      expect(f.commits, 1);
      expect(submits, 0);
    },
  );
  testWidgets(
    'notice persistence failure remains blocked and explicitly flagged',
    (tester) async {
      final f = AdmissionFixture()
        ..balance = 0
        ..refreshed = 0
        ..writeFails = true;
      final c = CallLaunchCoordinator(
        admission: f.service,
        submit: (_) async => fail('Must not launch'),
        onState: (_) {},
      );
      addTearDown(c.close);
      c.schedule(callRequest());
      await tester.pump(const Duration(milliseconds: 1500));
      expect(c.state.phase, CallLaunchPhase.blocked);
      expect(c.state.noticeSaveFailed, isTrue);
    },
  );
  testWidgets('close during async store read ignores all late effects', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final f = AdmissionFixture()..onRead = () => pending.future;
    final c = CallLaunchCoordinator(
      admission: f.service,
      submit: (_) async => fail('Must not launch'),
      onState: (_) {},
    );
    c.schedule(callRequest());
    await tester.pump(const Duration(milliseconds: 1500));
    expect(c.state.phase, CallLaunchPhase.checking);
    c.close();
    pending.complete(false);
    await tester.pump();
    expect(c.state.phase, CallLaunchPhase.closed);
    expect(f.commits, 0);
  });
  testWidgets('new input during balance refresh cannot confirm after refresh', (
    tester,
  ) async {
    final pending = Completer<int?>();
    final f = AdmissionFixture()
      ..balance = 0
      ..onRefresh = () => pending.future;
    await f.markNotified('session', callRequest().aliases);
    final c = CallLaunchCoordinator(
      admission: f.service,
      submit: (_) async => fail('Must not launch'),
      onState: (_) {},
    );
    addTearDown(c.close);
    c.schedule(callRequest());
    await tester.pump(const Duration(milliseconds: 1500));
    c.cancelPending();
    pending.complete(1000);
    await tester.pump();
    expect(c.state.phase, CallLaunchPhase.idle);
  });
  testWidgets('submit failure is uncertain, never automatically retried', (
    tester,
  ) async {
    final f = AdmissionFixture();
    var submits = 0;
    final c = CallLaunchCoordinator(
      admission: f.service,
      submit: (_) async {
        submits++;
        throw StateError('synthetic network');
      },
      onState: (_) {},
    );
    addTearDown(c.close);
    c.schedule(callRequest());
    await tester.pump(const Duration(milliseconds: 1500));
    expect(c.state.phase, CallLaunchPhase.uncertain);
    c.cancelPending();
    expect(c.schedule(callRequest()), isFalse);
    await tester.pump(const Duration(seconds: 30));
    expect(submits, 1);
  });
  testWidgets('account error on refresh fails closed and never submits', (
    tester,
  ) async {
    final f = AdmissionFixture()
      ..balance = 0
      ..onRefresh = () async => throw StateError('changed owner');
    await f.markNotified('session', callRequest().aliases);
    final c = CallLaunchCoordinator(
      admission: f.service,
      submit: (_) async => fail('Must not launch'),
      onState: (_) {},
    );
    addTearDown(c.close);
    c.schedule(callRequest());
    await tester.pump(const Duration(milliseconds: 1500));
    expect(c.state.phase, CallLaunchPhase.failed);
  });
  testWidgets(
    'batch request keeps its recipient count, coordinator never selects a route',
    (tester) async {
      final f = AdmissionFixture()
        ..balance = null
        ..refreshed = null;
      var count = 0;
      final c = CallLaunchCoordinator(
        admission: f.service,
        submit: (r) async {
          count = r.confirmation.recipientCount;
        },
        onState: (_) {},
      );
      addTearDown(c.close);
      c.schedule(callRequest(spec: {'recipientCount': 3}));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(count, 3);
      expect(f.commits, 0);
    },
  );
  testWidgets('reentrant close at submitting callback does not send', (
    tester,
  ) async {
    final f = AdmissionFixture();
    late CallLaunchCoordinator c;
    c = CallLaunchCoordinator(
      admission: f.service,
      submit: (_) async => fail('Must not launch'),
      onState: (s) {
        if (s.phase == CallLaunchPhase.submitting) c.close();
      },
    );
    c.schedule(callRequest());
    await tester.pump(const Duration(milliseconds: 1500));
    expect(c.state.phase, CallLaunchPhase.closed);
  });
}
