import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/conversation/data/voice/fallback_voice_input_session.dart';
import 'package:phone_agent/features/conversation/data/voice/asr_capture_session.dart';
import 'package:phone_agent/features/conversation/data/voice/device_pcm_capture.dart';
import 'package:phone_agent/core/audio/focused_pcm_capture.dart';
import 'package:phone_agent/core/audio/diagnosed_pcm_capture.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phone_agent/app/task_voice_transport_providers.dart';
import 'package:phone_agent/features/conversation/data/voice/signed_voice_socket.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'voice_socket_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'formal Android primary captures beginning before ASR ready and does not upload early',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      FlutterSecureStorage.setMockInitialValues({});
      const channel = MethodChannel('phone_agent/pcm_capture');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      Completer<Object?>? pending;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'read') {
          return (pending = Completer<Object?>()).future;
        }
        if (call.method == 'stop') {
          pending?.complete(null);
          pending = null;
        }
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final socket = VoiceSocketFake();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://synthetic.invalid/',
            ),
          ),
          currentAccountIdProvider.overrideWithValue(
            'synthetic-current-account',
          ),
          taskVoiceTransportProvider.overrideWithValue(_Transport(socket)),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(voiceInputFactoryProvider, (_, _) {});
      addTearDown(keepAlive.close);
      final session = container.read(voiceInputFactoryProvider)(() => true);
      addTearDown(session.cancel);
      await session.start(Uri.parse('ws://synthetic.invalid/asr'));
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((c) => c.method == 'start'), hasLength(1));
      expect((calls.first.arguments as Map)['speechInput'], true);
      final first = pending!;
      pending = null;
      first.complete(Uint8List.fromList([1, 2]));
      await Future<void>.delayed(Duration.zero);
      expect(socket.sent.whereType<Uint8List>(), isEmpty);
      socket.emit('{"type":"ready"}');
      await Future<void>.delayed(Duration.zero);
      expect(socket.sent.whereType<Uint8List>().single, [1, 2]);
      expect(socket.sent.first as String, contains('start_capture'));
      await session.cancel();
      expect(calls.where((c) => c.method == 'stop'), hasLength(1));
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test(
      'formal $platform factory captures early with platform voice processing',
      () {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'https://synthetic.invalid/',
              ),
            ),
            currentAccountIdProvider.overrideWithValue(
              'synthetic-current-account',
            ),
          ],
        );
        addTearDown(container.dispose);
        final keepAlive = container.listen(
          voiceInputFactoryProvider,
          (_, _) {},
        );
        addTearDown(keepAlive.close);
        final session =
            container.read(voiceInputFactoryProvider)(() => true)
                as FallbackVoiceInputSession;
        final fallback = session.createFallback() as AsrCaptureSession;
        expect(fallback.captureBeforeReady, true);
        final focused = fallback.capture as FocusedPcmCapture;
        final diagnosed = focused.delegate as DiagnosedPcmCapture;
        expect((diagnosed.delegate as DevicePcmCapture).speechInput, true);
      },
    );
  }
  test(
    'production factory binds current account, not sessionId or demo-user',
    () {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://synthetic.invalid/api/',
              runtimeApiBaseUrl: 'https://runtime.invalid/voice/',
            ),
          ),
          currentAccountIdProvider.overrideWithValue(
            'synthetic-current-account',
          ),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(voiceInputFactoryProvider, (_, _) {});
      addTearDown(keepAlive.close);
      final factory = container.read(voiceInputFactoryProvider);
      final session = factory(() => true) as FallbackVoiceInputSession;
      // Construction does not touch socket, microphone, credentials or hardware.
      expect(
        session.fallbackEndpoint.path,
        '/voice/ws/assistant/realtime/transcription',
      );
      expect(session.fallbackEndpoint.queryParameters, {
        'userId': 'synthetic-current-account',
        'languageCode': 'zh-CN',
      });
      expect(session.fallbackEndpoint.host, 'runtime.invalid');
    },
  );
}

// Only the signed socket boundary is substituted; the formal factory, capture
// adapter, ASR control protocol, local PCM buffer and audio lease execute normally.
class _Transport implements SignedVoiceSocket {
  _Transport(this.socket);
  final VoiceSocket socket;
  @override
  Future<VoiceSocket> open(Uri endpoint) async => socket;
  @override
  AccountSession get session => throw UnimplementedError();
  @override
  C1Transport get signing => throw UnimplementedError();
  @override
  Future<VoiceSocket> Function(Uri, Map<String, Object?>) get connect =>
      throw UnimplementedError();
}
