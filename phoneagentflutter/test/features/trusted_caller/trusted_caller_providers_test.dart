import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/trusted_caller_providers.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';

class MemoryStore implements SessionStore {
  AuthSession? saved = const AuthSession(
    accountId: 'first',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<AuthSession?> read() async => saved;
  @override
  Future<void> write(AuthSession session) async => saved = session;
  @override
  Future<void> clear() async => saved = null;
}

class ReportPort implements TrustedCallerPort {
  final readEntered = Completer<void>();
  Completer<TrustedCallerReport>? heldFirst;
  int prepares = 0, releases = 0, opens = 0;
  @override
  Future<bool> prepare(TrustedCallerOwner owner) async {
    prepares++;
    return true;
  }

  @override
  Future<TrustedCallerReport> readStatus(TrustedCallerOwner owner) async {
    if (!readEntered.isCompleted) readEntered.complete();
    if (owner.accountId == 'first' && heldFirst != null) {
      return heldFirst!.future;
    }
    return TrustedCallerReport(
      owner: owner,
      status: TrustedCallerStatus.notAuthorized,
    );
  }

  @override
  Future<void> openSettings(TrustedCallerOwner owner) async => opens++;
  @override
  Future<void> releaseSurface(TrustedCallerOwner owner) async => releases++;
}

void main() {
  test(
    'token refresh preserves surface; account or phone change replaces it',
    () async {
      final port = ReportPort();
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(MemoryStore()),
          trustedCallerPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(sessionControllerProvider.notifier);
      await session.restore();
      final subscription = container.listen(
        trustedCallerControllerProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      final first = container.read(trustedCallerControllerProvider.notifier);
      await first.refresh();
      expect(
        await session.replaceToken(session.credentials!, 'synthetic-refreshed'),
        true,
      );
      expect(
        container.read(trustedCallerControllerProvider.notifier),
        same(first),
      );
      for (final phone in ['13800000000', '13900000000']) {
        await session.accept(
          LoginOutcome(
            phone: phone,
            accountId: 'second',
            accessToken: 'synthetic-other',
            inviteRequired: false,
          ),
        );
        final current = container.read(
          trustedCallerControllerProvider.notifier,
        );
        await current.refresh();
        expect(current.owner.accountId, 'second');
        expect(current.owner.phone, phone);
        expect(current, isNot(same(first)));
      }
      expect(first.mounted, false);
      expect(port.releases, 2);
      expect(port.opens, 0);
    },
  );

  test('old explicit SDK report cannot enter a new account provider', () async {
    final port = ReportPort()..heldFirst = Completer<TrustedCallerReport>();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(MemoryStore()),
        trustedCallerPortProvider.overrideWithValue(port),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(sessionControllerProvider.notifier);
    await session.restore();
    final subscription = container.listen(
      trustedCallerControllerProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
    final first = container.read(trustedCallerControllerProvider.notifier);
    final pending = first.refresh();
    await port.readEntered.future;
    await session.accept(
      const LoginOutcome(
        phone: '13800000000',
        accountId: 'second',
        accessToken: 'synthetic-other',
        inviteRequired: false,
      ),
    );
    final second = container.read(trustedCallerControllerProvider.notifier);
    await second.refresh();
    port.heldFirst!.complete(
      TrustedCallerReport(
        owner: first.owner,
        status: TrustedCallerStatus.authorized,
        explicitSdkAuthorization: true,
      ),
    );
    await pending;
    expect(first.mounted, false);
    expect(
      container.read(trustedCallerControllerProvider).status,
      TrustedCallerStatus.notAuthorized,
    );
    expect(second.owner.accountId, 'second');
    expect(port.opens, 0);
  });

  test('signed out provider performs no SDK preparation', () async {
    final port = ReportPort();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(MemoryStore()..saved = null),
        trustedCallerPortProvider.overrideWithValue(port),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.notifier).restore();
    final subscription = container.listen(
      trustedCallerControllerProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
    await container.read(trustedCallerControllerProvider.notifier).refresh();
    expect(container.read(trustedCallerOwnerProvider), isNull);
    expect(port.prepares, 0);
    expect(port.opens, 0);
  });
}
