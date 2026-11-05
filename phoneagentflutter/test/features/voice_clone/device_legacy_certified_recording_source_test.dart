import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/voice_clone/data/device_legacy_certified_recording_source.dart';
import 'package:phone_agent/features/voice_clone/domain/certified_recording_store.dart';
import 'clone_candidate_api_test.dart' show recordingFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/legacy_certified_recording');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final prod = AppConfig.parse(
    environment: 'prod',
    apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
  );
  var calls = 0;
  Object? reply;
  Object? failure;
  DeviceLegacyCertifiedRecordingSource source({
    AppConfig? config,
    TargetPlatform platform = TargetPlatform.android,
    bool web = false,
    String account = 'phone-synthetic',
  }) => DeviceLegacyCertifiedRecordingSource(
    config: config ?? prod,
    accountId: account,
    platform: platform,
    web: web,
  );
  Map<String, Object?> fixture() {
    final recording = recordingFixture();
    return {
      'version': 1,
      'accountRef': 'phone-synthetic',
      'audio': recording.audio,
      'audioSha256': recording.audioSha256,
      'personFingerprint': recording.personFingerprint,
      'scriptVersion': recording.scriptVersion,
      'receipt': recording.receipt,
    };
  }

  setUp(() {
    calls = 0;
    failure = null;
    reply = fixture();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      expect(call.method, 'read');
      expect(call.arguments, isNull);
      if (failure != null) throw failure!;
      return reply;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'production Android imports matching account and verifies hash',
    () async {
      final result = await source().read();
      expect(result!.audio, recordingFixture().audio);
      expect(result.receipt, recordingFixture().receipt);
      expect(calls, 1);
    },
  );
  test('dev, wrong endpoint, iOS and Web never invoke native source', () async {
    for (final config in [
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
      ),
      AppConfig.parse(
        environment: 'prod',
        apiBaseUrl: 'https://agent.vvtech.tech/aiassistant-api/',
      ),
      AppConfig.parse(
        environment: 'prod',
        apiBaseUrl: 'https://chaken.ai:444/aiassistant-api/',
      ),
      AppConfig.parse(
        environment: 'prod',
        apiBaseUrl: 'https://chaken.ai/other/',
      ),
    ]) {
      expect(await source(config: config).read(), isNull);
    }
    expect(await source(platform: TargetPlatform.iOS).read(), isNull);
    expect(await source(web: true).read(), isNull);
    expect(calls, 0);
  });
  test(
    'missing source and another account are absent without consuming source',
    () async {
      reply = null;
      expect(await source().read(), isNull);
      reply = fixture()..['accountRef'] = 'phone-other';
      expect(await source().read(), isNull);
      expect(calls, 2);
    },
  );
  test('blank current account fails before native call', () async {
    await expectLater(
      source(account: ' ').read(),
      throwsA(RecordingStoreFailure.sessionChanged),
    );
    expect(calls, 0);
  });
  test('unknown source version remains unavailable and retryable', () async {
    reply = fixture()..['version'] = 2;
    await expectLater(
      source().read(),
      throwsA(RecordingStoreFailure.unavailable),
    );
  });
  test('invalid field types, empty audio and digest are corrupt', () async {
    for (final patch in <String, Object?>{
      'accountRef': null,
      'personFingerprint': '',
      'scriptVersion': 1,
      'receipt': ' ',
      'audioSha256': 'bad',
      'audio': Uint8List(0),
    }.entries) {
      reply = fixture()..[patch.key] = patch.value;
      await expectLater(
        source().read(),
        throwsA(RecordingStoreFailure.corrupt),
      );
    }
  });
  test(
    'native corruption and unavailable errors preserve sanitized categories',
    () async {
      failure = PlatformException(
        code: 'recording_corrupt',
        message: 'synthetic',
      );
      await expectLater(
        source().read(),
        throwsA(RecordingStoreFailure.corrupt),
      );
      failure = PlatformException(
        code: 'recording_unavailable',
        message: 'synthetic',
      );
      await expectLater(
        source().read(),
        throwsA(RecordingStoreFailure.unavailable),
      );
    },
  );
}
