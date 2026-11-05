import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_session_factory.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/domain/translation_call_finished.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_finished_recorder.dart';
import 'translation_finished_recorder_test.dart' show CountingRecords;

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'normal terminal emits once, start/connected times retained before return',
    () async {
      final fixture = PreviewTranslationSession();
      var now = DateTime(2026);
      final events = <TranslationCallFinished>[];
      final controller = TranslationSessionController(
        backend: fixture,
        mediaFactory: fixture.media,
        loadLanguages: fixture.languages,
        request: PreviewTranslationSession.request,
        now: () => now,
        onFinished: events.add,
      );
      addTearDown(controller.dispose);
      final start = controller.start();
      await flush();
      now = now.add(const Duration(seconds: 5));
      fixture.ready();
      await start;
      expect(events, isEmpty);
      fixture.connected();
      now = now.add(const Duration(seconds: 3));
      var beforeReturn = false;
      controller.addListener((state) {
        if (state.terminal) beforeReturn = events.length == 1;
      });
      fixture.ended();
      await controller.coordinator.stop();
      await controller.hangup();
      await controller.start();
      fixture.ended();
      expect(events, hasLength(1));
      expect(beforeReturn, isTrue);
      expect(
        events.single.startedAtMillis,
        DateTime(2026).millisecondsSinceEpoch,
      );
      expect(
        events.single.connectedAtMillis,
        DateTime(2026).add(const Duration(seconds: 5)).millisecondsSinceEpoch,
      );
      expect(
        events.single.endedAtMillis - events.single.connectedAtMillis!,
        3000,
      );
      expect(events.single.failed, isFalse);
    },
  );
  for (final scenario in ['create-failure', 'hangup-failure']) {
    test(
      '$scenario records failure without claiming connection or remote success',
      () async {
        final fixture = PreviewTranslationSession(scenario: scenario);
        final events = <TranslationCallFinished>[];
        final controller = TranslationSessionController(
          backend: fixture,
          mediaFactory: fixture.media,
          loadLanguages: fixture.languages,
          request: PreviewTranslationSession.request,
          onFinished: events.add,
        );
        addTearDown(controller.dispose);
        final start = controller.start();
        await flush();
        fixture.ready();
        await start;
        await controller.hangup();
        expect(events.single.failed, isTrue);
        expect(events.single.connectedAtMillis, isNull);
      },
    );
  }
  test(
    'factory finished save survives route disposal; rejects stale account before create',
    () async {
      final repo = CountingRecords()..gate = Completer<void>();
      var current = true;
      final recorder = TranslationFinishedRecorder(
        accountId: 'synthetic',
        repository: repo,
        isCurrent: () => current,
      );
      addTearDown(recorder.dispose);
      final factory = TranslationSessionFactory(recorder);
      final fixture = PreviewTranslationSession();
      TranslationSessionController create() => factory.create(
        backend: fixture,
        mediaFactory: fixture.media,
        loadLanguages: fixture.languages,
        request: PreviewTranslationSession.request,
        targetName: '合成',
        countryIso: 'US',
      );
      final controller = create();
      final start = controller.start();
      await flush();
      fixture.ready();
      await start;
      await controller.hangup();
      controller.dispose();
      repo.gate!.complete();
      await recorder.idle;
      expect(repo.rows.single.name, '合成');
      expect(repo.rows.single.countryIso, 'US');
      current = false;
      expect(create, throwsStateError);
      expect(fixture.creates, 1);
      expect(fixture.hangups, 1);
    },
  );
  test('finish callback may dispose before terminal state delivery', () async {
    final fixture = PreviewTranslationSession();
    final events = <TranslationCallFinished>[];
    late final TranslationSessionController controller;
    controller = TranslationSessionController(
      backend: fixture,
      mediaFactory: fixture.media,
      loadLanguages: fixture.languages,
      request: PreviewTranslationSession.request,
      onFinished: (event) {
        events.add(event);
        controller.dispose();
      },
    );
    final start = controller.start();
    await flush();
    fixture.ready();
    await start;
    await controller.hangup();
    expect(events, hasLength(1));
    expect(controller.mounted, isFalse);
  });
  test(
    'disposing an active controller never fabricates a Finished event',
    () async {
      final fixture = PreviewTranslationSession();
      final events = <TranslationCallFinished>[];
      final controller = TranslationSessionController(
        backend: fixture,
        mediaFactory: fixture.media,
        loadLanguages: fixture.languages,
        request: PreviewTranslationSession.request,
        onFinished: events.add,
      );
      final start = controller.start();
      await flush();
      controller.dispose();
      await start;
      await controller.coordinator.stop();
      expect(events, isEmpty);
    },
  );
}
