import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/identity/domain/identity_deletion_cleanup.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import '../../support/points_session_fixture.dart';

const launch = CloneCreationLaunch(
  CloneCreationModel(id: 'QWEN_OMNI_PLUS', name: '合成模型', pricePoints: 300),
  CloneCreationStart.authentication,
);
void main() {
  test(
    'production provider forwards masked prefill and retries cleanup without DELETE',
    () async {
      final identity = _Identity();
      var cleared = 0, skipped = 0;
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://example.test/',
            ),
          ),
          sessionStoreProvider.overrideWithValue(PointsSessionStore()),
          identityRepositoryProvider.overrideWithValue(identity),
          identityDeletedEffectProvider.overrideWithValue(
            () => IdentityDeletionCleanup(
              markSkipped: () async {
                skipped++;
              },
              clearRecording: () async {
                if (++cleared == 1) throw StateError('synthetic');
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sessionControllerProvider.notifier).restore();
      final keep = container.listen(cloneFlowProvider(launch), (_, __) {});
      addTearDown(keep.close);
      final flow = container.read(cloneFlowProvider(launch).notifier);
      flow.agree(true);
      await flow.next();
      expect(flow.state.verifiedIdCardMasked, '000***********0005');
      await flow.resetIdentity();
      expect(identity.deletes, 1);
      expect(flow.state.resetCleanupPending, isTrue);
      await flow.resetIdentity();
      expect(identity.deletes, 1);
      expect(skipped, 1);
      expect(cleared, 2);
      expect(flow.state.resetCleanupPending, isFalse);
      await container
          .read(sessionControllerProvider.notifier)
          .accept(
            const LoginOutcome(
              accountId: 'b',
              phone: '13800000000',
              accessToken: 'synthetic-b',
              inviteRequired: false,
            ),
          );
      // Old route service must not delete or clean the new account.
      await flow.services.resetIdentity!();
      expect(identity.deletes, 1);
      expect(cleared, 2);
    },
  );
}

class _Identity implements IdentityRepository {
  int deletes = 0;
  @override
  Future<IdentityProfile> load() async => const IdentityProfile(
    accountId: 'a',
    name: '合成姓名',
    verificationStatus: 'VERIFIED',
    certNoMasked: '000***********0005',
  );
  @override
  Future<IdentityProfile> delete() async {
    deletes++;
    return const IdentityProfile(accountId: 'a');
  }

  @override
  Future<IdentityProfile> save(IdentityDraft draft, {required bool verified}) =>
      throw UnimplementedError();
}
