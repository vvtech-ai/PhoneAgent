import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_task_speech_providers.dart';
import 'package:phone_agent/app/media_diagnostics_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/app/task_voice_settings_providers.dart';
import 'package:phone_agent/app/task_voice_transport_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/conversation/data/voice/conversation_tts_stream.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/conversation/data/voice/signed_voice_socket.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';
import 'package:phone_agent/features/settings/domain/task_voice.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../support/synthetic_account_api.dart';
import '../../../support/apology_provider_fixture.dart';
import 'voice_socket_fake.dart';

class _Credentials implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async =>
      throw StateError('offline');
}

class _Transport extends SignedVoiceSocket {
  _Transport(SyntheticAccountApi api) : super(api, C1Transport(_Credentials()));
  final sockets = <VoiceSocketFake>[];
  @override
  Future<VoiceSocket> open(Uri endpoint) async {
    final socket = VoiceSocketFake();
    sockets.add(socket);
    return socket;
  }
}

class _VoiceStore implements TaskVoiceStore {
  bool fail = false;
  TaskVoice voice = const TaskVoice('Maia', '', modelId: 'model-A');
  @override
  Future<TaskVoice> read() async {
    if (fail) throw StateError('catalog unavailable');
    return voice;
  }

  @override
  Future<void> write(TaskVoice value) async {
    voice = value;
  }
}

final _epoch = StateProvider<int>((_) => 1);
final _account = StateProvider<String>((_) => 'synthetic-account');
final _config = StateProvider<AppConfig>(
  (_) => AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://example.test/',
    runtimeApiBaseUrl: 'https://runtime.test/',
  ),
);
Future<void> tick() => Future<void>.delayed(Duration.zero);

class _Fixture {
  _Fixture() {
    transport = _Transport(api);
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith((ref) => ref.watch(_config)),
        loginEpochProvider.overrideWith((ref) => ref.watch(_epoch)),
        currentAccountIdProvider.overrideWith((ref) => ref.watch(_account)),
        taskVoiceTransportProvider.overrideWithValue(transport),
        taskVoiceStoreProvider.overrideWithValue(store),
        networkAvailabilityEventsProvider.overrideWithValue(
          const NoNetworkAvailabilityEvents(),
        ),
        mediaDiagnosticScopeFactoryProvider.overrideWithValue(
          () => MediaDiagnosticScope(events.add),
        ),
      ],
    );
  }
  final api = SyntheticAccountApi();
  final events = <DiagnosticEvent>[];
  final store = _VoiceStore();
  late final _Transport transport;
  late final ProviderContainer container;
  final holds = <ProviderSubscription<ConversationTaskSpeech?>>[];
  final entry = const ConversationEntry(sessionId: 'synthetic-task');
  ConversationTaskSpeech open([ConversationEntry? task]) {
    final provider = conversationTaskSpeechProvider(task ?? entry);
    holds.add(container.listen(provider, (_, __) {}));
    return container.read(provider)!;
  }

  void dispose() {
    for (final hold in holds) {
      hold.close();
    }
    container.dispose();
    api.api.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'task TTS uses the same 2s first audio timeout in every environment',
    () async {
      for (final environment in ['local', 'dev', 'test', 'prod']) {
        final fixture = _Fixture();
        fixture.container.read(_config.notifier).state = AppConfig.parse(
          environment: environment,
          apiBaseUrl: 'https://example.test/',
          runtimeApiBaseUrl: 'https://runtime.test/',
        );
        final taskSpeech = fixture.open();
        final reply =
            taskSpeech.factory(() => true, () {}) as ConversationTtsStream;
        final lease = reply.connectionOwner!.acquire();
        expect(lease.session.firstAudioTimeout, const Duration(seconds: 2));
        lease.release(cancelled: true);
        await reply.cancel();
        fixture.dispose();
      }
    },
  );
  test(
    'reply diagnostics correlate with receive on its reused task wire',
    () async {
      final fixture = _Fixture();
      final speech = fixture.open();
      final reply = speech.factory(() => true, () {}) as ConversationTtsStream;
      reply.enqueue('A');
      await tick();
      fixture.transport.sockets.single.emit('{"type":"ready"}');
      await tick();
      fixture.transport.sockets.single.emit([0, 0]);
      await tick();
      final receive = fixture.events.singleWhere(
        (e) => e.media?.stage == DiagnosticMediaStage.receive,
      );
      expect(receive.traceId, reply.diagnostics!.traceId);
      await reply.cancel();
      fixture.dispose();
    },
  );
  testWidgets(
    'accepted user input prepares once and task close ends ownership',
    (tester) async {
      const entry = ConversationEntry(
        sessionId: 'input-task',
        skillId: 'restaurant',
      );
      final fixture = ApologyProviderFixture(entry);
      addTearDown(fixture.dispose);
      await fixture.open(tester);
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      expect(controller.send('请帮我订餐'), isTrue);
      expect(fixture.speechPreparations, 1);
      controller.close();
      expect(fixture.speechClosures, 1);
      // Drain OfflineAgent's documented 100 ms delayed yield after cancellation.
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  test(
    'task entry handshakes before text and scope disposal closes wire',
    () async {
      final fixture = _Fixture();
      fixture.open();
      await tick();
      expect(fixture.transport.sockets, hasLength(1));
      expect(fixture.transport.sockets.single.sent, isEmpty);
      fixture.holds.single.close();
      await fixture.container.pump();
      expect(fixture.transport.sockets.single.closes, 1);
      fixture.dispose();
    },
  );
  test(
    'same speaker with changed actual model invalidates handshake snapshot',
    () async {
      final fixture = _Fixture();
      final speech = fixture.open();
      await tick();
      fixture.store.voice = const TaskVoice('Maia', '', modelId: 'model-B');
      await fixture.container.read(taskVoiceControllerProvider.notifier).load();
      await tick();
      expect(fixture.transport.sockets.single.closes, 1);
      speech.prepare();
      await tick();
      expect(fixture.transport.sockets, hasLength(2));
      fixture.dispose();
    },
  );
  test(
    'task account epoch and endpoint each own different physical wires',
    () async {
      final fixture = _Fixture();
      fixture.open();
      fixture.open(const ConversationEntry(sessionId: 'another-task'));
      await tick();
      expect(fixture.transport.sockets, hasLength(2));
      fixture.container.read(_epoch.notifier).state = 2;
      await fixture.container.pump();
      await tick();
      expect(fixture.transport.sockets.take(2).map((s) => s.closes), [1, 1]);
      expect(fixture.transport.sockets, hasLength(4));
      fixture.container.read(_account.notifier).state = 'another-account';
      await fixture.container.pump();
      await tick();
      expect(fixture.transport.sockets.skip(2).take(2).map((s) => s.closes), [
        1,
        1,
      ]);
      fixture.container.read(_config.notifier).state = AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/',
        runtimeApiBaseUrl: 'https://another-runtime.test/',
      );
      await fixture.container.pump();
      await tick();
      expect(fixture.transport.sockets.skip(4).take(2).map((s) => s.closes), [
        1,
        1,
      ]);
      expect(fixture.transport.sockets, hasLength(8));
      fixture.dispose();
    },
  );
  test('catalog failure keeps ordinary task handshake available', () async {
    final fixture = _Fixture();
    fixture.store.fail = true;
    fixture.open();
    await tick();
    expect(fixture.transport.sockets, hasLength(1));
    expect(fixture.transport.sockets.single.closes, 0);
    fixture.dispose();
  });
}
