import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/legacy_preferences_providers.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/app_update/data/device_legacy_preferences.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const source = DeviceLegacyPreferences();
  Object? payload;
  const local = MethodChannel('phone_agent/local_storage');
  final sandbox = <String, String>{};
  var calls = 0;
  setUp(() {
    calls = 0;
    sandbox.clear();
    messenger.setMockMethodCallHandler(local, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      if (call.method == 'write') sandbox[key] = args['value'] as String;
      return call.method == 'read' ? sandbox[key] : null;
    });
    payload = {'version': 1};
    messenger.setMockMethodCallHandler(DeviceLegacyPreferences.channel, (
      call,
    ) async {
      expect(call.method, 'read');
      expect(call.arguments, isNull);
      calls++;
      return payload;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(DeviceLegacyPreferences.channel, null);
    messenger.setMockMethodCallHandler(local, null);
    debugDefaultTargetPlatformOverride = null;
  });
  test('seven old language labels, aliases and both countries map', () async {
    for (final language in translationLanguages) {
      payload = {
        'version': 1,
        'translation': {
          'enabled': false,
          'prompt': false,
          'caller': language.label,
          'peer': '日语',
          'normalCountry': 'sg',
          'translationCountry': 'JP',
          'provider': 'OpenAi',
          'region': 'UnitedStates',
          'forceBackend': true,
        },
      };
      final result = (await source.readTranslation())!;
      expect(result.caller, language.code);
      expect(result.peer, 'ja');
      expect(result.normalCountry, 'SG');
      expect(result.translationCountry, 'JP');
      expect(result.provider, 'OPENAI');
      expect(result.region, 'US');
      expect(result.enabled, isFalse);
      expect(result.prompt, isFalse);
      expect(result.forceBackend, isTrue);
    }
  });
  test('unknown choices default; original levels clamp and round', () async {
    payload = {
      'version': 1,
      'translation': {
        'provider': 'domestic',
        'region': 'Japan',
        'caller': 'unknown',
        'normalCountry': 'ZZ',
      },
      'originalAudio': {'enabled': true, 'gain': 25, 'volume': 999},
    };
    final result = (await source.readTranslation())!;
    expect(result.provider, 'GEMINI');
    expect(result.region, 'JP');
    expect(result.caller, 'zh');
    expect(result.peer, 'en');
    expect(result.normalCountry, 'CN');
    expect((await source.readOriginalAudio())!.toJson(), {
      'version': 1,
      'enabled': true,
      'gain': 30,
      'volume': 100,
    });
  });
  test('absent source/section stays absent; malformed data fails', () async {
    for (final value in [
      null,
      {'version': 1},
    ]) {
      payload = value;
      expect(await source.readTranslation(), isNull);
      expect(await source.readOriginalAudio(), isNull);
    }
    for (final value in [
      {'version': 2},
      {'version': 1, 'translation': 'bad'},
      {
        'version': 1,
        'translation': {'enabled': 'false'},
      },
      {
        'version': 1,
        'translation': {'caller': 42},
      },
    ]) {
      payload = value;
      await expectLater(source.readTranslation(), throwsFormatException);
    }
    payload = {
      'version': 1,
      'originalAudio': {'gain': 2.5},
    };
    await expectLater(source.readOriginalAudio(), throwsFormatException);
  });
  test(
    'trusted location preserves timestamp and normalizes only ISO',
    () async {
      payload = {
        'version': 1,
        'location': {'countryIso': ' jp ', 'sampledAtMs': 123456789},
      };
      final value = (await source.readLocation())!;
      expect(value.countryIso, 'JP');
      expect(value.sampledAtMs, 123456789);
      expect(calls, 1);
    },
  );
  test('missing location never falls back to dial country', () async {
    payload = {
      'version': 1,
      'translation': {'normalCountry': 'JP', 'translationCountry': 'US'},
    };
    expect(await source.readLocation(), isNull);
    payload = null;
    expect(await source.readLocation(), isNull);
  });
  test(
    'invalid location fails instead of inventing country or sampling time',
    () async {
      for (final location in [
        'bad',
        <String, Object?>{},
        {'countryIso': 'JP'},
        {'countryIso': 'JP', 'sampledAtMs': '123'},
        {'countryIso': 'JP', 'sampledAtMs': 0},
        {'countryIso': 'JP', 'sampledAtMs': -1},
        {'countryIso': '+81', 'sampledAtMs': 123},
        {'countryIso': null, 'sampledAtMs': 123},
      ]) {
        payload = {'version': 1, 'location': location};
        await expectLater(source.readLocation(), throwsFormatException);
      }
    },
  );
  test(
    'formal stores import only Android precise prod and persist readback',
    () async {
      payload = {
        'version': 1,
        'translation': {'peer': '法语'},
        'originalAudio': {'gain': 20},
        'initialization': {'skipped': true},
        'location': {'countryIso': 'JP', 'sampledAtMs': 123456789},
      };
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final env in ['prod', 'dev']) {
          FlutterSecureStorage.setMockInitialValues({});
          debugDefaultTargetPlatformOverride = platform;
          final container = ProviderContainer(
            overrides: [
              appConfigProvider.overrideWithValue(
                AppConfig.parse(
                  environment: env,
                  apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
                ),
              ),
            ],
          );
          final eligible = platform == TargetPlatform.android && env == 'prod';
          expect(
            container.read(legacyPreferencesSourceProvider) != null,
            eligible,
          );
          final audio = container.read(originalAudioStoreProvider);
          final translation = container.read(
            translationPreferenceStoreProvider,
          );
          expect((await audio.read()).gain, eligible ? 20 : 50);
          expect((await translation.read()).peer, eligible ? 'fr' : 'en');
          await audio.read();
          await translation.read();
          final initialization = container.read(
            identityInitializationStoreProvider,
          );
          expect(await initialization.isSkipped(), eligible);
          final location = container.read(translationLocationStoreProvider);
          expect((await location.read())?.countryIso, eligible ? 'JP' : null);
          container.invalidate(translationLocationStoreProvider);
          expect(
            (await container.read(translationLocationStoreProvider).read())
                ?.sampledAtMs,
            eligible ? 123456789 : null,
          );
          container.invalidate(identityInitializationStoreProvider);
          expect(
            await container
                .read(identityInitializationStoreProvider)
                .isSkipped(),
            eligible,
          );
          container.dispose();
        }
      }
      expect(calls, 4);
    },
  );

  test(
    'initialization strictly maps present bool, not absent or malformed',
    () async {
      for (final value in [true, false]) {
        payload = {
          'version': 1,
          'initialization': {'skipped': value},
        };
        expect(await source.readInitializationSkipped(), value);
      }
      for (final value in [
        null,
        {'version': 1},
      ]) {
        payload = value;
        expect(await source.readInitializationSkipped(), isNull);
      }
      for (final value in [
        {'version': 2},
        {'version': 1, 'initialization': false},
        {'version': 1, 'initialization': <String, Object?>{}},
        {
          'version': 1,
          'initialization': {'skipped': 'true'},
        },
        {
          'version': 1,
          'initialization': {'skipped': null},
        },
      ]) {
        payload = value;
        await expectLater(
          source.readInitializationSkipped(),
          throwsFormatException,
        );
      }
    },
  );

  test('prod with different API cannot read legacy initialization', () async {
    FlutterSecureStorage.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            environment: 'prod',
            apiBaseUrl: 'https://example.test/api/',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(identityInitializationStoreProvider).isSkipped(),
      isFalse,
    );
    expect(calls, 0);
    expect(
      await container.read(translationLocationStoreProvider).read(),
      isNull,
    );
    expect(calls, 0);
  });
}
