import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/app/media_diagnostics_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_speech_providers.dart';
import 'package:phone_agent/app/tts_playback_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';
import 'package:phone_agent/core/audio/diagnosed_pcm_capture.dart';
import 'package:phone_agent/core/audio/diagnosed_pcm_output.dart';
import 'package:phone_agent/core/audio/focused_pcm_capture.dart';
import 'package:phone_agent/core/audio/focused_pcm_output.dart';
import 'package:phone_agent/features/conversation/data/voice/asr_capture_session.dart';
import 'package:phone_agent/features/conversation/data/voice/fallback_voice_input_session.dart';
import 'package:phone_agent/features/conversation/data/voice/realtime_transcription_session.dart';
import 'package:phone_agent/features/conversation/data/voice/conversation_tts_stream.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all three formal factories bind once, including delayed ASR fallback and TTS sentences',
    () {
      final events = <DiagnosticEvent>[];
      var bound = 0;
      final container = ProviderContainer(
        overrides: [
          networkAvailabilityEventsProvider.overrideWithValue(
            const NoNetworkAvailabilityEvents(),
          ),
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://synthetic.invalid/api/',
            ),
          ),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
          currentAccountIdProvider.overrideWithValue(
            'synthetic-current-account',
          ),
          mediaDiagnosticScopeFactoryProvider.overrideWithValue(() {
            bound++;
            return MediaDiagnosticScope(events.add);
          }),
        ],
      );
      addTearDown(container.dispose);
      final hold = container.listen(voiceInputFactoryProvider, (_, __) {});
      addTearDown(hold.close);
      final input =
          container.read(voiceInputFactoryProvider)(() => true)
              as FallbackVoiceInputSession;
      final fallback = input.createFallback() as AsrCaptureSession;
      final asr = fallback.asr as RealtimeTranscriptionSession;
      final capture =
          (fallback.capture as FocusedPcmCapture).delegate
              as DiagnosedPcmCapture;
      expect(asr.diagnostics!.traceId, capture.diagnostics.traceId);
      asr.diagnostics!.failure('ready_timeout');
      final speech =
          container.read(conversationSpeechFactoryProvider)!(() => true, () {})
              as ConversationTtsStream;
      addTearDown(speech.cancel);
      final sentenceA = speech.createSession();
      final sentenceB = speech.createSession();
      expect(sentenceA.diagnostics!.traceId, sentenceB.diagnostics!.traceId);
      sentenceA.diagnostics!.failure('first_audio_timeout');
      final preview = container.read(ttsPlaybackFactoryProvider)(
        () => true,
        () {},
      );
      final output =
          (preview.playback.output as FocusedPcmOutput).delegate
              as DiagnosedPcmOutput;
      expect(preview.tts.diagnostics!.traceId, output.diagnostics.traceId);
      output.diagnostics.record(
        DiagnosticMediaStage.stop,
        DiagnosticResult.succeeded,
      );
      expect(bound, 3);
      expect(events.length, 3);
      expect(events.map((e) => e.traceId).toSet().length, 3);
      // Constructed only: no native start/read/play, WebSocket, SMS or upload.
    },
  );
  test(
    'one factory survives login changes; delayed fallback/stop stay with original Journal',
    () async {
      final journals = <String, DiagnosticJournal>{};
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(environment: 'dev', apiBaseUrl: ''),
          ),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
          diagnosticJournalFactoryProvider.overrideWithValue(
            (scope) =>
                journals.putIfAbsent(scope, () => DiagnosticJournal(_Store())),
          ),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(sessionControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await session.accept(_login('a'));
      final factory = container.read(mediaDiagnosticScopeFactoryProvider);
      final a = factory();
      await session.signOut();
      await session.accept(_login('b'));
      expect(
        container.read(mediaDiagnosticScopeFactoryProvider),
        same(factory),
      );
      a
          .forComponent(DiagnosticMediaComponent.realtimeAsr)
          .failure('connect_failed');
      a
          .forComponent(DiagnosticMediaComponent.pcmCapture)
          .record(DiagnosticMediaStage.stop, DiagnosticResult.succeeded);
      final b = factory();
      b.forComponent(DiagnosticMediaComponent.taskTts).failure('ready_timeout');
      final aEvents = (await journals['dev|null|a']!.snapshot()).events;
      final bEvents = (await journals['dev|null|b']!.snapshot()).events;
      expect(aEvents.length, 2);
      expect(bEvents.length, 1);
      expect(aEvents.map((e) => e.traceId).toSet(), {a.traceId});
      expect(a.traceId, isNotEmpty);
      expect(bEvents.single.traceId, b.traceId);
      expect(a.traceId, isNot(b.traceId));
    },
  );
  test('journal factory failure returns a usable no-op scope', () {
    final container = ProviderContainer(
      overrides: [
        diagnosticJournalProvider.overrideWith(
          (_) => throw StateError('storage'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final scope = container.read(mediaDiagnosticScopeFactoryProvider)();
    expect(
      () => scope
          .forComponent(DiagnosticMediaComponent.taskAsr)
          .failure('connect_failed'),
      returnsNormally,
    );
  });
}

LoginOutcome _login(String id) => LoginOutcome(
  phone: '13800000000',
  inviteRequired: false,
  accountId: id,
  accessToken: 'synthetic',
);

class _SessionStore implements SessionStore {
  AuthSession? value;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _Store implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
  }
}
