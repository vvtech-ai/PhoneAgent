import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/app_update/data/device_legacy_preferences.dart';
import 'package:phone_agent/features/conversation/data/voice/fallback_voice_input_session.dart';
import '../../../support/local_storage_channel_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Object? payload;
  var nativeReads = 0;
  setUp(() {
    installLocalStorageChannelFake();
    nativeReads = 0;
    payload = {
      'version': 1,
      'voice': {'language': 'jp'},
    };
    FlutterSecureStorage.setMockInitialValues({});
    messenger.setMockMethodCallHandler(DeviceLegacyPreferences.channel, (
      call,
    ) async {
      expect(call.method, 'read');
      expect(call.arguments, isNull);
      nativeReads++;
      return payload;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(DeviceLegacyPreferences.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'voice section absent returns null; malformed types or versions reject',
    () async {
      const source = DeviceLegacyPreferences();
      expect(await source.readVoiceLanguage(), 'jp');
      for (final valid in [
        null,
        {'version': 1},
      ]) {
        payload = valid;
        expect(await source.readVoiceLanguage(), isNull);
      }
      for (final invalid in [
        {'version': 2},
        {'version': 1, 'voice': false},
        {
          'version': 1,
          'voice': {'language': 1},
        },
        {'version': 1, 'voice': {}},
      ]) {
        payload = invalid;
        await expectLater(source.readVoiceLanguage(), throwsFormatException);
      }
    },
  );
  test(
    'formal factory reads captured store only on Android exact prod scope',
    () async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final env in ['dev', 'prod']) {
          for (final url in [
            'https://chaken.ai/aiassistant-api/',
            'https://synthetic.invalid/',
          ]) {
            FlutterSecureStorage.setMockInitialValues({});
            final c = ProviderContainer(
              overrides: [
                appConfigProvider.overrideWithValue(
                  AppConfig.parse(environment: env, apiBaseUrl: url),
                ),
                currentAccountIdProvider.overrideWithValue('synthetic'),
              ],
            );
            final keep = c.listen(voiceInputFactoryProvider, (_, __) {});
            final session =
                c.read(voiceInputFactoryProvider)(() => true)
                    as FallbackVoiceInputSession;
            final expected =
                platform == TargetPlatform.android &&
                    env == 'prod' &&
                    url.contains('chaken.ai')
                ? 'ja-JP'
                : 'zh-CN';
            expect(await session.readLanguage!(), expected);
            expect(await session.readLanguage!(), expected);
            // Only configuration is read: no socket, microphone or credential use.
            keep.close();
            c.dispose();
          }
        }
      }
      expect(nativeReads, 1);
    },
  );
}
