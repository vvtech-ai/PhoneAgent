import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_recording_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../../support/synthetic_account_api.dart';

class _Store implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'a',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(AuthSession session) async {}
}

void main() {
  test(
    'production recording accepts SDK token URL with split service prefixes',
    () async {
      final wire = SyntheticAccountApi()
        ..data = {
          'url':
              'https://example.test/sdk/api/agent-calls/recording-content/${'a' * 32}',
        };
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://example.test/agent',
              sdkApiBaseUrl: 'https://example.test/sdk',
            ),
          ),
          sessionStoreProvider.overrideWithValue(_Store()),
          accountApiProvider.overrideWithValue(wire.api),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(wire.api.close);
      await container.read(sessionControllerProvider.notifier).restore();
      final provider = conversationRecordingsProvider(Object());
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      final manager = container.read(provider);
      final entry = manager.create('synthetic-call', manager.arbiter);
      addTearDown(entry.dispose);
      final asset = await entry.metadata.repository.load(
        retry: false,
        processing: () {},
      );
      expect(
        asset.remoteUri!.path,
        '/sdk/api/agent-calls/recording-content/${'a' * 32}',
      );
      expect(wire.requests.single.headers['Authorization'], 'Bearer synthetic');
      expect(wire.requests.single.method, 'POST');
    },
  );
}
