import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/trusted_caller_account_providers.dart';
import 'package:phone_agent/app/trusted_caller_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller_account.dart';

class MemoryAccountPort implements TrustedCallerAccountPort {
  final owners = <TrustedCallerOwner?>[];
  final environments = <String>[];
  @override
  Future<bool> updateAccount(
    TrustedCallerOwner? owner,
    String environment,
  ) async {
    owners.add(owner);
    environments.add(environment);
    return true;
  }
}

void main() {
  for (final initial in [SessionPhase.restoring, SessionPhase.signedOut]) {
    test(
      '$initial to signedIn delivers account without settings or guide',
      () async {
        final phase = StateProvider<SessionPhase>((_) => initial);
        final owner = StateProvider<TrustedCallerOwner?>((_) => null);
        final port = MemoryAccountPort();
        final container = ProviderContainer(
          overrides: [
            trustedCallerSessionPhaseProvider.overrideWith(
              (ref) => ref.watch(phase),
            ),
            trustedCallerOwnerProvider.overrideWith((ref) => ref.watch(owner)),
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'https://synthetic.invalid',
              ),
            ),
            trustedCallerAccountPortProvider.overrideWithValue(port),
          ],
        );
        final subscription = container.listen(
          trustedCallerAccountSyncProvider,
          (_, __) {},
        );
        await container.pump();
        const signedIn = TrustedCallerOwner('synthetic', 'synthetic', 1);
        container.read(owner.notifier).state = signedIn;
        container.read(phase.notifier).state = SessionPhase.signedIn;
        await container.pump();
        await Future<void>.delayed(Duration.zero);
        expect(port.owners.last, signedIn);
        expect(port.owners.whereType<TrustedCallerOwner>().length, 1);
        expect(port.environments.last, 'test');
        expect(container.exists(trustedCallerControllerProvider), false);
        subscription.close();
        container.dispose();
      },
    );
  }
  test(
    'restoring or failed restore never clears SDK; confirmed logout does',
    () async {
      final phase = StateProvider<SessionPhase>((_) => SessionPhase.restoring);
      final port = MemoryAccountPort();
      final container = ProviderContainer(
        overrides: [
          trustedCallerSessionPhaseProvider.overrideWith(
            (ref) => ref.watch(phase),
          ),
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://synthetic.invalid',
            ),
          ),
          trustedCallerOwnerProvider.overrideWithValue(null),
          trustedCallerAccountPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        trustedCallerAccountSyncProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      await container.pump();
      expect(port.owners, isEmpty);
      container.read(phase.notifier).state = SessionPhase.restoreFailed;
      await container.pump();
      expect(port.owners, isEmpty);
      container.read(phase.notifier).state = SessionPhase.signedOut;
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(port.owners, [null]);
    },
  );
  test(
    'account sync survives without settings and sends logout in order',
    () async {
      final ownerState = StateProvider<TrustedCallerOwner?>((ref) => null);
      final port = MemoryAccountPort();
      final container = ProviderContainer(
        overrides: [
          trustedCallerSessionPhaseProvider.overrideWithValue(
            SessionPhase.signedOut,
          ),
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://synthetic.invalid',
            ),
          ),
          trustedCallerOwnerProvider.overrideWith(
            (ref) => ref.watch(ownerState),
          ),
          trustedCallerAccountPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        trustedCallerAccountSyncProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      await container.pump();
      expect(port.owners, [null]);
      const first = TrustedCallerOwner('first', 'synthetic', 1);
      const second = TrustedCallerOwner('second', 'other-synthetic', 2);
      for (final owner in [first, null, second]) {
        container.read(ownerState.notifier).state = owner;
        await container.pump();
        await Future<void>.delayed(Duration.zero);
      }
      expect(port.owners, [null, first, null, second]);
      expect(port.environments, everyElement('test'));
      expect(container.exists(trustedCallerControllerProvider), false);
    },
  );
  test(
    'local or invalid configuration never registers signed-in owner',
    () async {
      for (final config in [
        AppConfig.parse(
          environment: 'local',
          apiBaseUrl: 'https://synthetic.invalid',
        ),
        AppConfig.parse(environment: 'dev', apiBaseUrl: ''),
      ]) {
        final port = MemoryAccountPort();
        final container = ProviderContainer(
          overrides: [
            trustedCallerSessionPhaseProvider.overrideWithValue(
              SessionPhase.signedOut,
            ),
            appConfigProvider.overrideWithValue(config),
            trustedCallerOwnerProvider.overrideWithValue(
              const TrustedCallerOwner('first', 'synthetic', 1),
            ),
            trustedCallerAccountPortProvider.overrideWithValue(port),
          ],
        );
        container.read(trustedCallerAccountSyncProvider);
        await container.pump();
        expect(port.owners, [null]);
        container.dispose();
      }
    },
  );
  test(
    'production account synchronization chooses pro without SDK proof',
    () async {
      final port = MemoryAccountPort();
      final container = ProviderContainer(
        overrides: [
          trustedCallerSessionPhaseProvider.overrideWithValue(
            SessionPhase.signedOut,
          ),
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'prod',
              apiBaseUrl: 'https://synthetic.invalid',
            ),
          ),
          trustedCallerOwnerProvider.overrideWithValue(
            const TrustedCallerOwner('first', 'synthetic', 1),
          ),
          trustedCallerAccountPortProvider.overrideWithValue(port),
        ],
      );
      container.read(trustedCallerAccountSyncProvider);
      await container.pump();
      expect(port.environments, ['pro']);
      expect(container.exists(trustedCallerControllerProvider), false);
      container.dispose();
    },
  );
}
