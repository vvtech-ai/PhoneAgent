import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/translation/data/sip/device_domestic_model_configuration.dart';
import 'package:phone_agent/app/domestic_translation_session_factory.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/data/recording/private_domestic_recording_files.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_encoder.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_model.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_call_plan.dart';
import 'package:phone_agent/features/translation/domain/translation_call_finished.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/domain/translation_pcm_bridge.dart';
import 'package:phone_agent/features/translation/domain/translation_realtime_event.dart';
import '../../support/synthetic_account_api.dart';

class Config implements DomesticModelConfigurationSource {
  bool available = true;
  Completer<DomesticModelConfiguration?>? pending;
  final value = DomesticModelConfiguration(
    provider: 'QWEN',
    uri: Uri.parse('wss://example.invalid'),
    headers: {'Authorization': 'synthetic'},
    model: 'synthetic',
  );
  @override
  Future<DomesticModelConfiguration?> load(String provider) async =>
      pending?.future ?? (available ? value : null);
}

class _Network implements NetworkAvailabilitySource {
  NetworkAvailability value = NetworkAvailability.available;
  Completer<NetworkAvailability>? pending;
  @override
  Future<NetworkAvailability> read() async => pending?.future ?? value;
}

Map<String, Object?> _points(String state) => {
  'billingSessionId': 'synthetic-points',
  'sessionState': state,
  'authorizedThroughMs': 60000,
  'authorizationVersion': 1,
  'connectedDurationMs': 0,
  'chargedPoints': 0,
  'availableBalance': 600,
  'heldBalance': 150,
  'stopState': 'NONE',
  'pricing': {
    'provider': 'QWEN',
    'modelId': 'QWEN',
    'firstMinutePoints': 150,
    'blockDurationMs': 6000,
    'blockPoints': 15,
    'priceVersion': 'synthetic',
  },
};

class Permissions implements ConversationPermissionSource {
  int calls = 0;
  PermissionGrant value = PermissionGrant.granted;
  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    calls++;
    return value;
  }
}

class Pcm implements TranslationPcmBridge {
  int starts = 0, closes = 0;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<Uint8List?> read() async => null;
  @override
  Future<void> play(TranslationAudio audio) async {}
  @override
  Future<void> setSpeaker(bool enabled) async {}
  @override
  Future<void> close() async {
    closes++;
  }
}

class Encoder implements DomesticRecordingEncoder {
  @override
  Future<void> encode({required String pcmPath, required String m4aPath}) =>
      throw StateError('Encoding must not start in admission tests');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SyntheticAccountApi http;
  late Config config;
  late Permissions permissions;
  late Pcm pcm;
  late AudioPlaybackFocus focus;
  late _Network network;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('domestic-composition');
    http = SyntheticAccountApi()..data = _points('PREPARED');
    network = _Network();
    config = Config();
    permissions = Permissions();
    pcm = Pcm();
    focus = AudioPlaybackFocus();
  });
  tearDown(() async {
    http.api.close();
    await root.delete(recursive: true);
  });
  final plan = TranslationCallPlan.resolve(
    location: TrustedTranslationLocation('CN', 1),
    rawNumber: '13800138000',
    targetCountry: 'CN',
    preferences: const TranslationPreferences(),
    domestic: const DomesticTranslationPreferences(
      domesticAccountId: 'synthetic',
    ),
  );
  const context = TranslationCallContext(
    clientCallId: 'synthetic-call',
    targetName: '合成',
  );
  DomesticTranslationSessionFactory factory({
    DomesticModelConfigurationSource? source,
  }) => DomesticTranslationSessionFactory(
    accountId: 'a',
    api: http.api,
    network: network,
    isCurrent: () => true,
    configurations: source ?? config,
    permissions: permissions,
    focus: focus,
    pcm: () => pcm,
    files: PrivateDomesticRecordingFiles(
      environment: 'test',
      apiBase: 'https://example.invalid',
      accountId: 'a',
      root: () async => root,
      isCurrent: () => true,
    ),
    encoder: Encoder(),
    readOriginalAudio: () async => const OriginalAudioSettings(),
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform native configuration passes factory admission without starting a call',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        const channel = MethodChannel(
          'com.vvtech.phone_agent/domestic_model_configuration',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (_) async => {
                'provider': 'QWEN',
                'uri': 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime',
                'model': 'qwen3-livetranslate-flash-realtime',
                'voice': 'Nofish',
                'outputSampleRate': 24000,
                'headers': {'Authorization': 'Bearer synthetic-admission-only'},
              },
            );
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
        final source = DeviceDomesticModelConfigurationSource(
          appConfig: AppConfig.parse(
            environment: 'dev',
            apiBaseUrl: 'https://example.invalid',
          ),
        );
        final owner = factory(source: source);
        final controller = await owner.create(plan, context);
        expect(controller.plan, same(plan));
        expect(permissions.calls, greaterThan(0));
        expect(focus.active, isNotNull);
        expect(pcm.starts, 0);
        expect(http.requests.length, 1);
        expect(http.requests.single.path, contains('points/usage-sessions'));
        http.data = _points('SETTLED');
        controller.dispose();
        await owner.close();
        expect(focus.active, isNull);
        expect(http.requests.length, 2);
      },
    );
  }
  test(
    'missing secure configuration refuses before permission, points, SIP and capture',
    () async {
      config.available = false;
      final owner = factory();
      await expectLater(owner.create(plan, context), throwsA(anything));
      expect(permissions.calls, 0);
      expect(http.requests, isEmpty);
      expect(pcm.starts, 0);
      expect(focus.active, isNull);
      await owner.close();
    },
  );
  test(
    'admission prepares points before returning, without model or SIP or capture',
    () async {
      final owner = factory();
      final controller = await owner.create(plan, context);
      expect(controller.plan, same(plan));
      expect(focus.active, isNotNull);
      expect(pcm.starts, 0);
      expect(http.requests.length, 1);
      await expectLater(owner.create(plan, context), throwsA(anything));
      http.data = _points('SETTLED');
      controller.dispose();
      await owner.close();
      expect(focus.active, isNull);
      expect(http.requests.length, 2);
      await owner.close();
    },
  );
  test(
    'permission denial prevents financial allocation and closes prepared resources',
    () async {
      permissions.value = PermissionGrant.denied;
      final owner = factory();
      await expectLater(owner.create(plan, context), throwsA(anything));
      expect(permissions.calls, 2);
      expect(http.requests, isEmpty);
      expect(pcm.starts, 0);
      expect(pcm.closes, 1);
      await owner.close();
    },
  );
  test(
    'closing during safe configuration load cancels admission without replay',
    () async {
      config.pending = Completer<DomesticModelConfiguration?>();
      final owner = factory();
      final creating = owner.create(plan, context);
      final failed = expectLater(creating, throwsA(anything));
      await owner.close();
      await failed;
      config.pending!.complete(config.value);
      await Future<void>.delayed(Duration.zero);
      expect(http.requests, isEmpty);
      expect(permissions.calls, 0);
      expect(focus.active, isNull);
    },
  );
  test('offline admission stays before points and call connections', () async {
    network.value = NetworkAvailability.unavailable;
    final owner = factory();
    await expectLater(
      owner.create(plan, context),
      throwsA(
        isA<TranslationPlanFailure>().having(
          (e) => e.message,
          'native text',
          '当前无可用网络',
        ),
      ),
    );
    expect(http.requests, isEmpty);
    expect(pcm.starts, 0);
    expect(focus.active, isNull);
    await owner.close();
  });
  test(
    'network wait cancellation completes before late available evidence',
    () async {
      network.pending = Completer<NetworkAvailability>();
      final owner = factory();
      final creating = owner.create(plan, context);
      final failed = expectLater(creating, throwsA(anything));
      await Future<void>.delayed(Duration.zero);
      await owner.close();
      await failed;
      network.pending!.complete(NetworkAvailability.available);
      await Future<void>.delayed(Duration.zero);
      expect(http.requests, isEmpty);
      expect(pcm.starts, 0);
      expect(focus.active, isNull);
    },
  );
}
