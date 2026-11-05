import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_session_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  test(
    'production factory is lazy, rebinds login epoch and rejects old owner',
    () async {
      final server = SyntheticAccountApi()
        ..data = {
          'callId': 'call',
          'taskId': 'task',
          'callState': 'CONNECTED',
          'backendCallEnabled': true,
          'handoffSupported': false,
          'appRtcRequired': false,
        };
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(_Store()),
          accountApiProvider.overrideWith((ref) {
            ref.watch(loginEpochProvider);
            final api = AccountApi(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'https://example.test',
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
      final session = container.read(sessionControllerProvider.notifier);
      await session.restore();
      final subscription = container.listen(
        callSessionRepositoryProvider,
        (_, __) {},
        onError: (_, __) {},
      );
      addTearDown(subscription.close);
      final old = container.read(callSessionRepositoryProvider);
      expect(server.requests, isEmpty);
      await old.status(CallSessionTarget(taskId: 'task'));
      expect((server.requests.last.data as Map)['userId'], 'a');
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          accountId: 'b',
          inviteRequired: false,
          accessToken: 'synthetic-b',
        ),
      );
      final current = container.read(callSessionRepositoryProvider);
      expect(identical(old, current), isFalse);
      await expectLater(
        old.status(CallSessionTarget(taskId: 'task')),
        throwsA(ApiFailure.sessionChanged),
      );
      await current.status(CallSessionTarget(taskId: 'task'));
      expect((server.requests.last.data as Map)['userId'], 'b');
      expect(server.requests.length, 2);
      await session.signOut();
      expect(
        () => container.read(callSessionRepositoryProvider),
        throwsA(ApiFailure.signedOut),
      );
    },
  );
}

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
