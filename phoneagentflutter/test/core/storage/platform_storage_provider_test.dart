import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/data/ios_session_store.dart';
import 'package:phone_agent/features/auth/data/migrating_session_store.dart';
import 'package:phone_agent/features/auth/data/secure_session_store.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform retains correct production authentication implementation',
      () {
        debugDefaultTargetPlatformOverride = platform;
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                environment: 'prod',
                apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(
          container.read(sessionStoreProvider),
          platform == TargetPlatform.iOS
              ? isA<IosSessionStore>()
              : isA<MigratingSessionStore>(),
        );
      },
    );
  }
  test('Android test environment retains existing secure session store', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            environment: 'test',
            apiBaseUrl: 'https://example.test/aiassistant-api/',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(sessionStoreProvider), isA<SecureSessionStore>());
  });
}
