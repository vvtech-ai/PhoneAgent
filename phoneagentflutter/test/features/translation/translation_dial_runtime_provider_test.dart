import '../../support/synthetic_account_api.dart';
import '../../support/translation_directory_fixture.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/app/translation_catalog_providers.dart';
import 'package:phone_agent/app/translation_dial_binding_provider.dart';
import 'package:phone_agent/app/translation_dial_runtime_providers.dart';
import 'package:phone_agent/app/translation_finished_providers.dart';
import 'package:phone_agent/app/translation_session_factory.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/data/http_translation_backend_repository.dart';
import 'package:phone_agent/features/translation/data/http_translation_catalog_repository.dart';
import 'package:phone_agent/features/translation/domain/translation_dial_request.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_finished_recorder.dart';
import '../../../tool/previews/auth_scenario.dart';
import 'translation_dial_runtime_test.dart' show dial;
import 'translation_finished_recorder_test.dart' show CountingRecords;
import '../conversation/voice/voice_input_fake.dart' show InputPermissionFake;

class _Original implements OriginalAudioStore {
  @override
  Future<OriginalAudioSettings> read() async =>
      const OriginalAudioSettings(enabled: true, gain: 25, volume: 60);
  @override
  Future<void> write(OriginalAudioSettings value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final (mobile, country) in [
    (TargetPlatform.android, 'US'),
    (TargetPlatform.android, 'JP'),
    (TargetPlatform.iOS, 'US'),
    (TargetPlatform.iOS, 'JP'),
  ]) {
    test(
      '$mobile simulated $country uses environment nodes; account/audio isolation survives refresh',
      () async {
        debugDefaultTargetPlatformOverride = mobile;
        final auth = AuthScenario(AuthScenarioKind.direct)
          ..saved = const AuthSession(
            accountId: 'owner',
            phone: '13800000000',
            accessToken: 'synthetic',
          );
        final recorder = TranslationFinishedRecorder(
          accountId: 'owner',
          repository: CountingRecords(),
          isCurrent: () => true,
        );
        addTearDown(recorder.dispose);
        final http = SyntheticAccountApi()..data = translationOptionsFixture();
        if (country == 'JP') {
          // The active Android gateway does not require a directory node.
          for (final item in (http.data as Map)['countries'] as List) {
            (item as Map)['nodeEndpoint'] = '';
          }
        }
        addTearDown(http.api.close);
        final container = ProviderContainer(
          overrides: [
            accountApiProvider.overrideWithValue(http.api),
            translationAccessProvider.overrideWithValue(
              TranslationAccess(countryIso: country, forced: false),
            ),
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'https://account.example.invalid/',
              ),
            ),
            sessionStoreProvider.overrideWithValue(auth),
            originalAudioStoreProvider.overrideWithValue(_Original()),
            conversationPermissionSourceProvider.overrideWithValue(
              InputPermissionFake(),
            ),
            translationEndpointProvider.overrideWithValue(
              (region) =>
                  Uri.parse('https://${region.toLowerCase()}.example.invalid/'),
            ),
            translationSessionFactoryProvider.overrideWithValue(
              TranslationSessionFactory(recorder),
            ),
          ],
        );
        addTearDown(container.dispose);
        final session = container.read(sessionControllerProvider.notifier);
        await session.restore();
        final runtime = container.read(translationDialRuntimeProvider)!;
        expect(
          runtime.media,
          same(container.read(translationDeviceMediaFactoryProvider)),
        );
        final services = runtime.openServices('JP');
        expect(
          (services.backend as HttpTranslationBackendRepository).base,
          Uri.parse('https://jp.example.invalid/'),
        );
        services.close();
        final resolved = await runtime.resolveServices!(dial());
        expect(
          (resolved.backend as HttpTranslationBackendRepository).base,
          Uri.parse('https://jp.example.invalid/'),
        );
        resolved.close();
        final originalDial = dial();
        final us = await runtime.resolveServices!(
          TranslationDialRequest(
            rawNumber: originalDial.phone,
            countryIso: originalDial.countryIso,
            displayName: originalDial.displayName,
            preferences: originalDial.preferences.copy(region: 'US'),
          ),
        );
        expect(
          (us.backend as HttpTranslationBackendRepository).base,
          Uri.parse('https://us.example.invalid/'),
        );
        us.close();
        final catalog =
            container.read(translationCatalogRepositoryProvider)
                as HttpTranslationCatalogRepository;
        expect(
          catalog.endpoint('JP'),
          Uri.parse('https://jp.example.invalid/'),
        );
        expect(
          catalog.endpoint('US'),
          Uri.parse('https://us.example.invalid/'),
        );
        final native = await runtime.resolveServices!(
          TranslationDialRequest(
            rawNumber: originalDial.phone,
            countryIso: originalDial.countryIso,
            callerCountryIso: country,
            displayName: originalDial.displayName,
            preferences: originalDial.preferences,
          ),
        );
        expect(
          (native.backend as HttpTranslationBackendRepository).base,
          Uri.parse('https://${country.toLowerCase()}.example.invalid/'),
        );
        native.close();
        final binding = container.read(translationDialSessionBindingProvider)!;
        final call =
            await binding.create(dial()) as TranslationSessionController;
        expect(call.request.userId, 'owner');
        expect(call.request.originalAudioPercent, 25);
        expect(call.request.originalAudioVolumePercent, 60);
        call.dispose();
        await Future<void>.delayed(Duration.zero);
        await session.replaceToken(session.credentials!, 'synthetic-refreshed');
        expect(container.read(translationDialRuntimeProvider), same(runtime));
        await session.signOut();
        expect(container.read(translationDialRuntimeProvider), isNull);
        expect(container.read(translationDialSessionBindingProvider), isNull);
        expect(runtime.current, isFalse);
        await expectLater(runtime.create(dial()), throwsStateError);
        expect(auth.sends, 0);
      },
    );
  }
}
