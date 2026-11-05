import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import '../../support/points_session_fixture.dart';

const launch = CloneCreationLaunch(
  CloneCreationModel(pricePoints: 300, id: 'QWEN_OMNI_PLUS', name: 'Qwen'),
  CloneCreationStart.authentication,
);
CloneCandidate candidate(CloneBillingStatus billing) => CloneCandidate(
  id: 'synthetic-candidate',
  modelId: 'QWEN_OMNI_PLUS',
  status: CloneCandidateStatus.ready,
  source: CloneCandidateSource.verification,
  billing: billing,
  chargedPoints: 300,
  remainingPoints: 1,
  providerAssetId: 'asset',
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'both formal clone admission paths publish fresh balance to shared wallet',
    () async {
      final f = PointsSessionFixture();
      addTearDown(f.dispose);
      await f.restore();
      final creation = f.container.read(cloneCreationPortProvider);
      await f.container
          .read(pointsWalletControllerProvider.notifier)
          .initialize();
      f.repository.balance = 810;
      expect(await creation.availablePoints(), 810);
      expect(
        f.container.read(pointsWalletControllerProvider).admissionBalance,
        810,
      );
      final keep = f.container.listen(cloneFlowProvider(launch), (_, __) {});
      addTearDown(keep.close);
      final flow = f.container.read(cloneFlowProvider(launch).notifier);
      f.repository.balance = 720;
      expect(await flow.services.points(), 720);
      expect(
        f.container.read(pointsWalletControllerProvider).admissionBalance,
        720,
      );
    },
  );
  test(
    'formal billing hook queries server, deduplicates candidate and ignores historical remaining balance',
    () async {
      final f = PointsSessionFixture();
      addTearDown(f.dispose);
      await f.restore();
      final keep = f.container.listen(cloneFlowProvider(launch), (_, __) {});
      addTearDown(keep.close);
      final flow = f.container.read(cloneFlowProvider(launch).notifier);
      await f.container
          .read(pointsWalletControllerProvider.notifier)
          .initialize();
      final before = f.repository.accounts;
      f.repository.balance = 620;
      flow.services.onBilling!(
        candidate(CloneBillingStatus.notReserved),
        false,
      );
      await flush();
      expect(f.repository.accounts, before);
      flow.services.onBilling!(candidate(CloneBillingStatus.charged), false);
      flow.services.onBilling!(candidate(CloneBillingStatus.charged), false);
      await flush();
      expect(f.repository.accounts, before + 1);
      expect(
        f.container.read(pointsWalletControllerProvider).admissionBalance,
        620,
      );
      flow.services.onBilling!(candidate(CloneBillingStatus.charged), true);
      flow.services.onBilling!(candidate(CloneBillingStatus.charged), true);
      await flush();
      expect(f.repository.accounts, before + 2);
      await f.container
          .read(sessionControllerProvider.notifier)
          .accept(
            const LoginOutcome(
              phone: '13800000000',
              accountId: 'b',
              accessToken: 'synthetic-b',
              inviteRequired: false,
            ),
          );
      await f.container
          .read(pointsWalletControllerProvider.notifier)
          .initialize();
      final afterSwitch = f.repository.accounts;
      flow.services.onBilling!(candidate(CloneBillingStatus.released), false);
      await flush();
      expect(f.repository.accounts, afterSwitch);
    },
  );
}
