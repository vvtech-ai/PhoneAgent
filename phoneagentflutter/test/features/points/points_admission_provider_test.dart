import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_admission_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../../support/synthetic_account_api.dart';

class _Store implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'a',
    phone: '13800000000',
    accessToken: 'synthetic-a',
  );
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(AuthSession session) async {}
}

void main() {
  test(
    'production admission publishes balance to wallet and isolates login epoch',
    () async {
      final server = SyntheticAccountApi()
        ..data = {
          'totalBalance': 350,
          'availableBalance': 300,
          'heldBalance': 50,
          'updatedAt': 'synthetic',
        };
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(_Store()),
          accountApiProvider.overrideWith((ref) {
            ref.watch(loginEpochProvider);
            final api = AccountApi(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'https://example.test/',
              ),
              ref.read(sessionControllerProvider.notifier),
              client: Dio()..httpClientAdapter = server,
            );
            ref.onDispose(api.close);
            return api;
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(server.api.close);
      final session = container.read(sessionControllerProvider.notifier);
      await session.restore();
      final keep = container.listen(
        callAdmissionProvider('synthetic-session'),
        (_, __) {},
      );
      addTearDown(keep.close);
      final admission = container.read(
        callAdmissionProvider('synthetic-session'),
      );
      final wallet = container.read(pointsWalletControllerProvider.notifier);
      // Wait for the deliberately unsupported synthetic ledger/model responses;
      // the admission account call must still be able to update shared state.
      await Future<void>.delayed(Duration.zero);
      expect(await admission.refreshBalance(), 300);
      expect(admission.readBalance(), 300);
      expect(
        container
            .read(pointsWalletControllerProvider)
            .account!
            .availableBalance,
        300,
      );
      expect(
        container.read(pointsWalletControllerProvider).ledgerStale,
        isTrue,
      );
      server.status = 503;
      expect(await admission.refreshBalance(), isNull);
      expect(admission.readBalance(), isNull);
      expect(
        container
            .read(pointsWalletControllerProvider)
            .account!
            .availableBalance,
        300,
      );
      server.status = 200;
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          accountId: 'b',
          accessToken: 'synthetic-b',
          inviteRequired: false,
        ),
      );
      final replacement = container.read(
        callAdmissionProvider('synthetic-session'),
      );
      expect(identical(admission, replacement), isFalse);
      expect(
        identical(
          wallet,
          container.read(pointsWalletControllerProvider.notifier),
        ),
        isFalse,
      );
      await expectLater(
        admission.refreshBalance(),
        throwsA(anyOf(isA<StateError>(), ApiFailure.sessionChanged)),
      );
      expect(await replacement.refreshBalance(), 300);
      expect(
        server.requests.every((request) => request.method == 'GET'),
        isTrue,
      );
    },
  );
}
