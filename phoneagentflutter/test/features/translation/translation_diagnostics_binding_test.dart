import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/app/translation_device_media_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/translation/data/app_audio_translation_media.dart';
import 'package:phone_agent/features/translation/data/livekit_translation_media.dart';
import 'package:phone_agent/features/translation/domain/translation_media_port.dart';

const _sessionId = '11111111-2222-4333-8444-555555555555';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform formal factories retain original account across login replacement',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final journals = <String, DiagnosticJournal>{};
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.parse(environment: 'dev', apiBaseUrl: ''),
            ),
            sessionStoreProvider.overrideWithValue(_SessionStore()),
            diagnosticJournalFactoryProvider.overrideWithValue(
              (scope) => journals.putIfAbsent(
                scope,
                () => DiagnosticJournal(_Store()),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final session = container.read(sessionControllerProvider.notifier);
        await Future<void>.delayed(Duration.zero);
        await session.accept(_login('a'));
        final factory = container.read(translationDeviceMediaFactoryProvider)!;
        final live =
            factory(TranslationMediaTransport.liveKit, () => true)
                as LiveKitTranslationMedia;
        final ws =
            factory(TranslationMediaTransport.websocket, () => true)
                as AppAudioTranslationMedia;
        expect(
          live.diagnostics!.component,
          DiagnosticMediaComponent.translationLivekit,
        );
        expect(
          ws.diagnostics!.component,
          DiagnosticMediaComponent.translationAppAudio,
        );
        expect(live.diagnostics!.traceId, isNotEmpty);
        await session.signOut();
        await session.accept(_login('b'));
        expect(
          container.read(translationDeviceMediaFactoryProvider),
          same(factory),
        );
        live.diagnostics!
            .withSession(_sessionId)
            .record(DiagnosticMediaStage.close, DiagnosticResult.succeeded);
        ws.diagnostics!
            .withSession(_sessionId)
            .record(DiagnosticMediaStage.close, DiagnosticResult.failed);
        final next =
            factory(TranslationMediaTransport.websocket, () => true)
                as AppAudioTranslationMedia;
        next.diagnostics!.record(
          DiagnosticMediaStage.connect,
          DiagnosticResult.started,
        );
        final a = (await journals['dev|null|a']!.snapshot()).events;
        final b = (await journals['dev|null|b']!.snapshot()).events;
        expect(a.length, 2);
        expect(a.map((e) => e.sessionId).toSet(), {_sessionId});
        expect(a.map((e) => e.traceId).toSet(), {
          live.diagnostics!.traceId,
          ws.diagnostics!.traceId,
        });
        expect(b.length, 1);
        expect(b.single.traceId, next.diagnostics!.traceId);
        expect(b.single.traceId, isNot(ws.diagnostics!.traceId));
        // Factories only: no connect/start/close call that could acquire a native bridge.
      },
    );
  }

  test(
    'new components and stages survive Journal reload and ZIP; session and extra fields sanitized',
    () async {
      final store = _Store();
      final journal = DiagnosticJournal(store);
      addTearDown(journal.close);
      final stages = [
        DiagnosticMediaStage.permission,
        DiagnosticMediaStage.roomReady,
        DiagnosticMediaStage.merchantReady,
        DiagnosticMediaStage.microphone,
        DiagnosticMediaStage.speaker,
        DiagnosticMediaStage.dtmf,
      ];
      for (final component in [
        DiagnosticMediaComponent.translationLivekit,
        DiagnosticMediaComponent.translationAppAudio,
      ]) {
        for (final stage in stages) {
          MediaDiagnostics(
            journal.record,
            component,
            sessionId: _sessionId,
          ).record(stage, DiagnosticResult.received);
        }
      }
      final dirty = DiagnosticEvent(
        operation: DiagnosticOperation.voiceMedia,
        result: DiagnosticResult.failed,
      ).toJson();
      dirty['sessionId'] = 'private-session-token';
      dirty['media'] = {
        'component': 'translationLivekit',
        'stage': 'dtmf',
        'reason': 'private-exception',
        'digit': '#',
        'text': 'private-transcript',
      };
      journal.record(DiagnosticEvent.fromJson(dirty));
      await journal.snapshot();
      final restored = DiagnosticJournal(store);
      addTearDown(restored.close);
      final zip = await ZipLogRepository(
        restored,
        uploadBundle: (_) async => fail('No upload'),
      ).prepare();
      final text = utf8.decode(
        ZipDecoder().decodeBytes(zip.bytes).files.single.content as List<int>,
      );
      expect(zip.count, 13);
      expect(text, contains(_sessionId));
      expect(text, contains('translationLivekit'));
      expect(text, contains('translationAppAudio'));
      for (final stage in stages) {
        expect(text, contains(stage.name));
      }
      for (final forbidden in ['private', 'digit', '#', 'transcript']) {
        expect(text, isNot(contains(forbidden)));
      }
      final events = (await restored.snapshot()).events;
      expect(events.last.sessionId, isEmpty);
      expect(events.last.media!.reason, DiagnosticMediaReason.unknown);
    },
  );

  test(
    'session-bound failing diagnostic sink never escapes into media caller',
    () {
      final sink = MediaDiagnostics(
        (_) => throw StateError('synthetic storage failure'),
        DiagnosticMediaComponent.translationAppAudio,
      );
      expect(
        () => sink
            .withSession(_sessionId)
            .record(DiagnosticMediaStage.play, DiagnosticResult.failed),
        returnsNormally,
      );
    },
  );
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
