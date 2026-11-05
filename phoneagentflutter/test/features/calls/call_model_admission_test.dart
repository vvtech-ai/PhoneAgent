import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_admission_service.dart';
import 'package:phone_agent/features/calls/domain/call_launch_coordinator.dart';
import '../../support/call_admission_fixture.dart';

void main() {
  for (final at in ['delay', 'admission read', 'submitting']) {
    testWidgets('model revoked during $at prevents submit and permits retry', (
      tester,
    ) async {
      final fixture = AdmissionFixture();
      var ready = true, submits = 0, revokeAtSubmit = true;
      if (at == 'admission read') {
        fixture.onRead = () async {
          ready = false;
          return false;
        };
      }
      final service = CallAdmissionService(
        store: fixture,
        notices: fixture,
        readBalance: () => 100000,
        readModel: () => ready ? 'model' : null,
        refreshBalance: () async => 100000,
        modelAvailable: () => ready,
      );
      final launch = CallLaunchCoordinator(
        admission: service,
        submit: (_) async {
          submits++;
        },
        onState: (state) {
          if (at == 'submitting' &&
              revokeAtSubmit &&
              state.phase == CallLaunchPhase.submitting) {
            ready = false;
          }
        },
      );
      addTearDown(launch.close);
      launch.schedule(callRequest());
      if (at == 'delay') ready = false;
      await tester.pump(const Duration(seconds: 2));
      expect(submits, 0);
      expect(launch.state.phase, CallLaunchPhase.failed);
      expect(fixture.commits, 0);
      ready = true;
      fixture.onRead = null;
      launch.reportPresented(
        callRequest().identity,
        callRequest().specSignature,
      );
      // Disable the one-shot reentrant revocation before retrying.
      revokeAtSubmit = false;
      expect(launch.confirmCurrent('确认拨打'), isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(submits, 1);
    });
  }
}
