import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/translation/data/sip/device_domestic_model_configuration.dart';
import 'package:phone_agent/features/translation/data/sip/doubao_translation_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    'com.vvtech.phone_agent/domestic_model_configuration',
  );
  final valid = AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://api.example.test',
  );
  Map<String, Object> model(String provider) => {
    'provider': provider,
    'uri': provider == 'QWEN'
        ? 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime'
        : 'wss://openspeech.bytedance.com/api/v4/ast/v2/translate',
    'model': provider == 'QWEN'
        ? 'qwen3-livetranslate-flash-realtime'
        : 'volc.service_type.10053',
    'voice': 'Nofish',
    'outputSampleRate': provider == 'QWEN' ? 24000 : 16000,
    'headers': provider == 'QWEN'
        ? {'Authorization': 'Bearer synthetic-model-only'}
        : {
            'X-Api-Key': 'synthetic-model-only',
            'X-Api-Resource-Id': 'volc.service_type.10053',
          },
  };
  Object? response;
  var calls = 0;
  setUp(() {
    calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls++;
          expect(call.method, 'read');
          expect((call.arguments as Map).keys, ['provider']);
          if (response is PlatformException) {
            throw response! as PlatformException;
          }
          return response;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final provider in ['QWEN', 'DOUBAO']) {
      test(
        '$platform $provider legacy adapter reads native reference config',
        () async {
          debugDefaultTargetPlatformOverride = platform;
          response = model(provider);
          final config = await DeviceDomesticModelConfigurationSource(
            appConfig: valid,
          ).load(provider);
          expect(config, isNotNull);
          expect(config!.voice, 'Nofish');
          expect(config.outputSampleRate, provider == 'QWEN' ? 24000 : 16000);
          expect(config.toString(), isNot(contains('synthetic-model-only')));
          expect(calls, 1);
          if (provider == 'DOUBAO') {
            final protocol = DoubaoTranslationProtocol(
              configuration: config,
              leg: 'local',
              sourceLanguage: 'zh',
              targetLanguage: 'en',
              token: () => 'synthetic-session',
            );
            final baseline = protocol.start();
            expect(baseline, isNotEmpty);
            expect(String.fromCharCodes(baseline), isNot(contains('Nofish')));
          }
        },
      );
    }
    test(
      '$platform missing malformed and private errors stay unavailable',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final source = DeviceDomesticModelConfigurationSource(appConfig: valid);
        final bad = <Object?>[
          null,
          'invalid',
          {...model('QWEN'), 'provider': 'DOUBAO'},
          {...model('QWEN'), 'uri': 'wss://invalid.example'},
          {...model('QWEN'), 'outputSampleRate': 16000},
          {...model('QWEN'), 'voice': ''},
          {
            ...model('QWEN'),
            'headers': {'Authorization': 'Bearer synthetic\ninvalid'},
          },
          {
            ...model('QWEN'),
            'headers': {'Authorization': 'Bearer '},
          },
          {
            ...model('QWEN'),
            'headers': {
              'Authorization': 'Bearer synthetic',
              'X-Account-Id': 'unexpected',
            },
          },
          PlatformException(code: 'PRIVATE', details: 'synthetic-private'),
        ];
        for (final value in bad) {
          response = value;
          expect(await source.load('QWEN'), isNull);
        }
        expect(calls, bad.length);
      },
    );
  }
  test(
    'invalid API unsupported platform and unknown provider make zero native calls',
    () async {
      response = model('QWEN');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        await DeviceDomesticModelConfigurationSource(
          appConfig: AppConfig.parse(environment: 'dev', apiBaseUrl: ''),
        ).load('QWEN'),
        isNull,
      );
      final source = DeviceDomesticModelConfigurationSource(appConfig: valid);
      expect(await source.load('UNKNOWN'), isNull);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(await source.load('QWEN'), isNull);
      expect(calls, 0);
    },
  );
  test(
    'Doubao access-key fallback is accepted and mixed auth is rejected',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final source = DeviceDomesticModelConfigurationSource(appConfig: valid);
      response = {
        ...model('DOUBAO'),
        'headers': {
          'X-Api-Access-Key': 'synthetic-access',
          'X-Api-Resource-Id': 'volc.service_type.10053',
        },
      };
      expect(await source.load('DOUBAO'), isNotNull);
      response = {
        ...model('DOUBAO'),
        'headers': {
          'X-Api-Key': 'synthetic',
          'X-Api-Access-Key': 'synthetic',
          'X-Api-Resource-Id': 'volc.service_type.10053',
        },
      };
      expect(await source.load('DOUBAO'), isNull);
    },
  );
}
