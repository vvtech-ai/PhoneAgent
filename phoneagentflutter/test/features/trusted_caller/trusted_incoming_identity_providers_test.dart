import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/trusted_caller_providers.dart';
import 'package:phone_agent/app/trusted_incoming_identity_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';

class IncomingMemoryStore implements SessionStore {
  AuthSession? session = const AuthSession(
    accountId: 'first',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<AuthSession?> read() async => session;
  @override
  Future<void> write(AuthSession value) async => session = value;
  @override
  Future<void> clear() async => session = null;
}

class IncomingMemoryPort implements TrustedIncomingIdentityPort {
  final sources = <StreamController<TrustedIncomingIdentity?>>[];
  final owners = <TrustedCallerOwner>[];
  final environments = <String>[];
  var cancellations = 0;
  @override
  Stream<TrustedIncomingIdentity?> watch(
    TrustedCallerOwner owner,
    String environment,
  ) {
    owners.add(owner);
    environments.add(environment);
    final source = StreamController<TrustedIncomingIdentity?>.broadcast(
      onCancel: () => cancellations++,
    );
    sources.add(source);
    return source.stream;
  }

  Future<void> close() async {
    for (final source in sources) {
      await source.close();
    }
  }
}

void main() {
  test(
    'token refresh retains incoming owner stream; account replacement rejects old report',
    () async {
      final port = IncomingMemoryPort();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://synthetic.invalid',
            ),
          ),
          sessionStoreProvider.overrideWithValue(IncomingMemoryStore()),
          trustedIncomingIdentityPortProvider.overrideWithValue(port),
        ],
      );
      final session = container.read(sessionControllerProvider.notifier);
      await session.restore();
      final subscription = container.listen(
        trustedIncomingIdentityControllerProvider,
        (_, __) {},
      );
      final first = container.read(
        trustedIncomingIdentityControllerProvider.notifier,
      );
      expect(port.sources, hasLength(1));
      expect(
        await session.replaceToken(session.credentials!, 'synthetic-refreshed'),
        true,
      );
      await container.pump();
      expect(
        container.read(trustedIncomingIdentityControllerProvider.notifier),
        same(first),
      );
      expect(port.sources, hasLength(1));
      await session.accept(
        const LoginOutcome(
          phone: '13900000000',
          accountId: 'second',
          accessToken: 'synthetic-other',
          inviteRequired: false,
        ),
      );
      await container.pump();
      expect(port.cancellations, 1);
      expect(port.sources, hasLength(2));
      final old = TrustedIncomingIdentity(
        owner: port.owners.first,
        eventId: 'old',
        verification: TrustedIdentityVerification.verified,
      );
      port.sources.last.add(old);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(trustedIncomingIdentityControllerProvider), isNull);
      port.sources.last.add(
        TrustedIncomingIdentity(
          owner: port.owners.last,
          eventId: 'current',
          verification: TrustedIdentityVerification.verified,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(trustedIncomingIdentityControllerProvider)?.eventId,
        'current',
      );
      await session.signOut();
      await container.pump();
      expect(container.read(trustedIncomingIdentityControllerProvider), isNull);
      expect(port.sources, hasLength(2));
      expect(port.cancellations, 2);
      expect(container.exists(trustedCallerControllerProvider), false);
      subscription.close();
      container.dispose();
      await port.close();
    },
  );
  test(
    'local configuration never subscribes signed-in account to native identity',
    () async {
      final port = IncomingMemoryPort();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'local',
              apiBaseUrl: 'https://synthetic.invalid',
            ),
          ),
          trustedCallerOwnerProvider.overrideWithValue(
            const TrustedCallerOwner('synthetic', 'synthetic-phone', 1),
          ),
          trustedIncomingIdentityPortProvider.overrideWithValue(port),
        ],
      );
      final subscription = container.listen(
        trustedIncomingIdentityControllerProvider,
        (_, __) {},
      );
      await container.pump();
      expect(port.sources, isEmpty);
      expect(container.read(trustedIncomingIdentityControllerProvider), isNull);
      subscription.close();
      container.dispose();
      await port.close();
    },
  );
}
