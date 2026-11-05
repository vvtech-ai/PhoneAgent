import 'dart:async';
import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/translation/data/livekit_translation_media.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import '../conversation/voice/voice_input_fake.dart';
import 'translation_livekit_room_fake.dart';

void main() {
  late TranslationLiveKitRoomFake room;
  late LiveKitTranslationMedia media;
  late List<DiagnosticEvent> logs;
  var current = true;
  setUp(() {
    room = TranslationLiveKitRoomFake();
    logs = [];
    current = true;
    media = LiveKitTranslationMedia(
      roomFactory: () => room,
      permissions: InputPermissionFake(),
      focus: AudioPlaybackFocus(),
      isCurrent: () => current,
      diagnostics: MediaDiagnostics(
        logs.add,
        DiagnosticMediaComponent.translationLivekit,
      ),
    );
    media.events.listen((_) {}, onError: (Object _) {});
  });
  tearDown(() async {
    room.failClose = false;
    await media.close();
  });
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  void ready([String id = 'mock-session']) =>
      room.wire({'event': 'realtime_ready', 'callSessionId': id});
  int count(DiagnosticMediaStage stage, DiagnosticResult result) =>
      logs.where((e) => e.media!.stage == stage && e.result == result).length;
  Future<void> connected() async {
    final pending = media.connect(PreviewTranslationSession.ticket);
    await tick();
    ready();
    await pending;
  }

  test(
    'room connection is not readiness; duplicate and wrong-session ready ignored',
    () async {
      final pending = media.connect(PreviewTranslationSession.ticket);
      await tick();
      expect(
        count(DiagnosticMediaStage.connect, DiagnosticResult.succeeded),
        1,
      );
      expect(
        count(DiagnosticMediaStage.roomReady, DiagnosticResult.succeeded),
        1,
      );
      expect(count(DiagnosticMediaStage.ready, DiagnosticResult.succeeded), 0);
      ready('wrong-session');
      expect(count(DiagnosticMediaStage.ready, DiagnosticResult.received), 0);
      ready();
      ready();
      await pending;
      expect(count(DiagnosticMediaStage.ready, DiagnosticResult.received), 1);
      expect(count(DiagnosticMediaStage.ready, DiagnosticResult.succeeded), 1);
      await media.setMuted(true);
      await media.setSpeaker(true);
      await media.sendDtmf('#');
      room.wire({'event': 'error', 'code': 'private-provider-message'});
      final text = jsonEncode(logs.map((e) => e.toJson()).toList());
      for (final secret in [
        '#',
        'private-provider-message',
        'example.invalid',
        'synthetic',
        'mock-session',
        'digit',
      ]) {
        expect(text, isNot(contains(secret)));
      }
      expect(count(DiagnosticMediaStage.dtmf, DiagnosticResult.succeeded), 1);
      expect(logs.last.media!.reason, DiagnosticMediaReason.providerError);
    },
  );

  test('cancelled late connection is never logged as usable', () async {
    room.connectGate = Completer<void>();
    final pending = expectLater(
      media.connect(PreviewTranslationSession.ticket),
      throwsStateError,
    );
    await tick();
    current = false;
    final closing = media.close();
    room.connectGate!.complete();
    await pending;
    await closing;
    expect(count(DiagnosticMediaStage.connect, DiagnosticResult.succeeded), 0);
    expect(count(DiagnosticMediaStage.ready, DiagnosticResult.succeeded), 0);
    expect(count(DiagnosticMediaStage.connect, DiagnosticResult.cancelled), 1);
  });

  test('control failure and close retry preserve actual results', () async {
    await connected();
    room.failControl = true;
    await expectLater(media.setSpeaker(true), throwsStateError);
    expect(count(DiagnosticMediaStage.speaker, DiagnosticResult.failed), 1);
    room.failClose = true;
    await expectLater(media.close(), throwsStateError);
    expect(count(DiagnosticMediaStage.close, DiagnosticResult.succeeded), 0);
    expect(count(DiagnosticMediaStage.close, DiagnosticResult.failed), 1);
    room.failClose = false;
    await media.close();
    expect(count(DiagnosticMediaStage.close, DiagnosticResult.succeeded), 1);
  });

  test('transport failure is failed, not a user cancellation', () async {
    final pending = expectLater(
      media.connect(PreviewTranslationSession.ticket),
      throwsStateError,
    );
    await tick();
    room.controller.addError(StateError('private-socket-error'));
    await pending;
    expect(
      logs.any((e) => e.media!.reason == DiagnosticMediaReason.transportError),
      true,
    );
    expect(count(DiagnosticMediaStage.ready, DiagnosticResult.failed), 1);
    expect(logs.any((e) => e.result == DiagnosticResult.cancelled), false);
  });

  test(
    'ready timeout has a fixed category without waiting wall-clock seconds',
    () {
      fakeAsync((clock) {
        final timedRoom = TranslationLiveKitRoomFake();
        final timedMedia = LiveKitTranslationMedia(
          roomFactory: () => timedRoom,
          permissions: InputPermissionFake(),
          focus: AudioPlaybackFocus(),
          isCurrent: () => true,
          diagnostics: MediaDiagnostics(
            logs.add,
            DiagnosticMediaComponent.translationLivekit,
          ),
        );
        timedMedia.events.listen((_) {}, onError: (Object _) {});
        var failed = false;
        timedMedia.connect(PreviewTranslationSession.ticket).catchError((
          Object _,
        ) {
          failed = true;
        });
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 11));
        clock.flushMicrotasks();
        expect(failed, true);
        expect(
          logs.any(
            (e) => e.media!.reason == DiagnosticMediaReason.readyTimeout,
          ),
          true,
        );
        expect(
          count(DiagnosticMediaStage.ready, DiagnosticResult.succeeded),
          0,
        );
      });
    },
  );
}
