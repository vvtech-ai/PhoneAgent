import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/conversation_speech_providers.dart';
import 'package:phone_agent/app/task_voice_settings_providers.dart';
import 'package:phone_agent/app/media_diagnostics_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/task_voice_preview_providers.dart';
import 'package:phone_agent/app/task_voice_transport_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/conversation/data/voice/signed_voice_socket.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket.dart';
import 'package:phone_agent/features/settings/domain/task_voice.dart';
import 'package:phone_agent/features/settings/data/api_task_voice_store.dart';
import '../../support/synthetic_account_api.dart';
import '../conversation/voice/voice_socket_fake.dart';

class _UnusedCredentials implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async =>
      throw StateError('offline');
}

class _FailedStore implements TaskVoiceStore {
  @override
  Future<TaskVoice> read() async => throw StateError('catalog unavailable');
  @override
  Future<void> write(TaskVoice voice) async =>
      throw StateError('catalog unavailable');
}

class _Transport extends SignedVoiceSocket {
  _Transport(this.socket, SyntheticAccountApi api)
    : super(api, C1Transport(_UnusedCredentials()));
  final VoiceSocketFake socket;
  @override
  Future<VoiceSocket> open(Uri endpoint) async => socket;
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'ordinary task speech opens even when the settings catalog is unavailable',
    () async {
      final wire = SyntheticAccountApi();
      final socket = VoiceSocketFake();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://example.test/aiassistant-api/',
              runtimeApiBaseUrl: 'https://example.test/aiassistant-runtime/',
            ),
          ),
          taskVoiceStoreProvider.overrideWithValue(_FailedStore()),
          taskVoiceTransportProvider.overrideWithValue(
            _Transport(socket, wire),
          ),
          mediaDiagnosticScopeFactoryProvider.overrideWithValue(
            () => MediaDiagnosticScope((_) {}),
          ),
        ],
      );
      final hold = container.listen(
        conversationSpeechFactoryProvider,
        (_, __) {},
      );
      final playback = container.read(conversationSpeechFactoryProvider)!(
        () => true,
        () {},
      );
      addTearDown(() async {
        await playback.cancel();
        hold.close();
        container.dispose();
        wire.api.close();
      });
      playback.enqueue('普通任务回复');
      playback.complete();
      await tick();
      await tick();
      socket.emit('{"type":"ready"}');
      await tick();
      await tick();
      expect(socket.sent, isNotEmpty);
      final frame =
          jsonDecode(socket.sent.whereType<String>().first)
              as Map<String, dynamic>;
      expect(frame.containsKey('purpose'), isFalse);
    },
  );
  test(
    'formal task preview uses the App v1.6.0 SDK audio preview endpoint',
    () async {
      final wire = SyntheticAccountApi();
      wire.beforeResponse = (request) async {
        wire.data = request.method == 'POST'
            ? {'url': 'http://synthetic.invalid/invalid.wav'}
            : {
                'modelId': 'task-tts',
                'selectedVoice': 'Ethan',
                'defaultVoice': 'Ethan',
                'voices': [
                  {'voice': 'Ethan', 'displayName': 'Ethan'},
                  {'voice': 'Maia', 'displayName': 'Maia'},
                ],
              };
      };
      final socket = VoiceSocketFake();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://example.test/aiassistant-api/',
              runtimeApiBaseUrl: 'https://example.test/aiassistant-runtime/',
            ),
          ),
          loginEpochProvider.overrideWithValue(1),
          accountApiProvider.overrideWithValue(wire.api),
          taskVoiceStoreProvider.overrideWithValue(ApiTaskVoiceStore(wire.api)),
          taskVoiceTransportProvider.overrideWithValue(
            _Transport(socket, wire),
          ),
        ],
      );
      final provider = taskVoicePreviewProvider(Object());
      final hold = container.listen(provider, (_, __) {});
      final preview = container.read(provider.notifier);
      addTearDown(() async {
        await preview.stop();
        hold.close();
        container.dispose();
        wire.api.close();
      });
      await preview.toggle(TaskVoice.maia);
      await tick();
      await tick();
      expect(wire.requests, hasLength(2));
      expect(
        wire.requests.first.uri.path,
        '/api/account/settings/task-tts-voice',
      );
      expect(wire.requests.last.method, 'POST');
      expect(
        wire.requests.last.uri.path,
        '/api/account/settings/system-voice-preview/models/task-tts/voices/Maia',
      );
      expect(wire.requests.any((request) => request.method == 'PUT'), isFalse);
      expect(
        preview.state.error,
        isNotEmpty,
        reason:
            'invalid HTTP sample address is rejected without native playback',
      );
    },
  );
}
