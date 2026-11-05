import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_dial_runtime.dart';
import 'package:phone_agent/app/translation_session_factory.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_dial_request.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_finished_recorder.dart';
import 'translation_finished_recorder_test.dart' show CountingRecords;

Future<void> flush() => Future<void>.delayed(Duration.zero);
TranslationDialRequest dial() => TranslationDialRequest(
  rawNumber: '2025550123',
  countryIso: 'US',
  displayName: '合成目标',
  preferences: const TranslationPreferences(
    region: 'JP',
    provider: 'OPENAI',
    caller: 'fr',
    peer: 'ja',
  ),
);

class DelayedCreate extends PreviewTranslationSession {
  final gate = Completer<TranslationBackendSession>();
  @override
  Future<TranslationBackendSession> create(
    TranslationCreateRequest request,
  ) async {
    await super.create(request);
    return gate.future;
  }
}

class RuntimeFixture {
  RuntimeFixture({
    PreviewTranslationSession? backend,
    Future<void> Function()? preflight,
  }) : backend = backend ?? PreviewTranslationSession() {
    recorder = TranslationFinishedRecorder(
      accountId: 'synthetic',
      repository: records,
      isCurrent: () => current,
    );
    runtime = TranslationDialRuntime(
      accountId: 'synthetic',
      isCurrent: () => current,
      prepareMedia: preflight,
      sessions: TranslationSessionFactory(recorder),
      media: (transport, current) {
        expect(current(), isTrue);
        return this.backend.media(transport);
      },
      openServices: (region) {
        regions.add(region);
        return TranslationDialServices(
          backend: this.backend,
          languages: this.backend.languages,
          close: () {
            closes++;
            this.backend.trace.add('http-close');
          },
        );
      },
      readOriginalAudio: () async {
        if (audioFailure) throw StateError('Synthetic read failure');
        return audioGate == null
            ? const OriginalAudioSettings(enabled: true, gain: 30, volume: 70)
            : await audioGate!.future;
      },
    );
  }
  final PreviewTranslationSession backend;
  final records = CountingRecords();
  late final TranslationFinishedRecorder recorder;
  late final TranslationDialRuntime runtime;
  bool current = true, audioFailure = false;
  Completer<OriginalAudioSettings>? audioGate;
  final regions = <String>[];
  int closes = 0;
  Future<void> close() async {
    await runtime.close();
    recorder.dispose();
  }
}

void main() {
  test(
    'preflight must finish before opening services; failure and logout create nothing',
    () async {
      final gate = Completer<void>();
      final f = RuntimeFixture(preflight: () => gate.future);
      addTearDown(f.close);
      final pending = f.runtime.create(dial());
      await flush();
      expect(f.regions, isEmpty);
      final assertion = expectLater(pending, throwsStateError);
      f.current = false;
      gate.complete();
      await assertion;
      expect(f.regions, isEmpty);
      f.current = true;
      final failing = RuntimeFixture(
        preflight: () async => throw StateError('denied'),
      );
      addTearDown(failing.close);
      await expectLater(failing.runtime.create(dial()), throwsStateError);
      expect(failing.regions, isEmpty);
    },
  );
  for (final scenario in ['normal', 'fallback']) {
    test(
      'runtime $scenario keeps snapshot, readiness and finished record',
      () async {
        final f = RuntimeFixture(
          backend: PreviewTranslationSession(scenario: scenario),
        );
        addTearDown(f.close);
        final controller = await f.runtime.create(dial());
        expect(f.regions, ['JP']);
        await expectLater(f.runtime.create(dial()), throwsStateError);
        final work = controller.start();
        await flush();
        expect(f.backend.merchants, 0);
        f.backend.ready();
        await work;
        expect(f.backend.merchants, 1);
        expect(f.backend.lastCreate!.userId, 'synthetic');
        expect(f.backend.lastCreate!.phone, '+12025550123');
        expect(f.backend.lastCreate!.provider, 'OPENAI');
        expect(f.backend.lastCreate!.userLanguage, 'fr');
        expect(f.backend.lastCreate!.merchantLanguage, 'ja-JP');
        expect(f.backend.lastCreate!.originalAudioPercent, 30);
        expect(f.backend.lastCreate!.originalAudioVolumePercent, 70);
        if (scenario == 'fallback') {
          expect(
            f.backend.trace,
            containsAllInOrder([
              'connect:liveKit',
              'close:liveKit',
              'connect:websocket',
            ]),
          );
        }
        f.backend.connected();
        await controller.hangup();
        controller.dispose();
        await f.recorder.idle;
        await flush();
        expect(f.closes, 1);
        expect(f.backend.trace, containsAllInOrder(['hangup', 'http-close']));
        expect(f.records.rows.single.name, '合成目标');
        expect(f.records.rows.single.countryIso, 'US');
      },
    );
  }
  test('closing while original audio loads never opens HTTP', () async {
    final f = RuntimeFixture()..audioGate = Completer<OriginalAudioSettings>();
    addTearDown(f.close);
    final pending = f.runtime.create(dial());
    final rejected = expectLater(pending, throwsStateError);
    await expectLater(f.runtime.create(dial()), throwsStateError);
    await f.runtime.close();
    f.audioGate!.complete(const OriginalAudioSettings());
    await rejected;
    expect(f.regions, isEmpty);
    expect(f.backend.creates, 0);
  });
  test(
    'original audio read failure cannot dial with defaults; retry allowed',
    () async {
      final f = RuntimeFixture()..audioFailure = true;
      addTearDown(f.close);
      await expectLater(f.runtime.create(dial()), throwsStateError);
      expect(f.regions, isEmpty);
      f.audioFailure = false;
      final controller = await f.runtime.create(dial());
      controller.dispose();
      await flush();
      expect(f.closes, 1);
      expect(f.backend.creates, 0);
    },
  );
  for (final closeRuntime in [true, false]) {
    test(
      'logout during create cleans old session before HTTP close ($closeRuntime)',
      () async {
        final backend = DelayedCreate();
        final f = RuntimeFixture(backend: backend);
        addTearDown(f.close);
        final controller = await f.runtime.create(dial());
        final work = controller.start();
        await flush();
        expect(backend.creates, 1);
        f.current = false;
        final closing = closeRuntime ? f.runtime.close() : Future<void>.value();
        await flush();
        expect(f.closes, 0);
        backend.gate.complete(PreviewTranslationSession.ticket);
        await work;
        await closing;
        controller.dispose();
        await flush();
        expect(backend.merchants, 0);
        expect(backend.hangups, 1);
        expect(
          backend.trace,
          containsAllInOrder(['create', 'hangup', 'http-close']),
        );
        expect(f.closes, 1);
        expect(f.records.rows, isEmpty);
      },
    );
  }
}
