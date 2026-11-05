import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/translation/data/app_audio_translation_media.dart';
import 'package:phone_agent/features/translation/data/preview_app_audio_ports.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import '../conversation/voice/voice_input_fake.dart';

void main() {
  late PreviewAppAudioSocket socket;
  late _Pcm audio;
  late AppAudioTranslationMedia media;
  late List<DiagnosticEvent> logs;
  setUp(() {
    socket = PreviewAppAudioSocket();
    audio = _Pcm();
    logs = [];
    media = AppAudioTranslationMedia(
      connector: (_) async => socket,
      audio: audio,
      permissions: InputPermissionFake(),
      focus: AudioPlaybackFocus(),
      isCurrent: () => true,
      diagnostics: MediaDiagnostics(
        logs.add,
        DiagnosticMediaComponent.translationAppAudio,
      ),
    );
    media.events.listen((_) {}, onError: (Object _) {});
  });
  tearDown(() async {
    audio.failClose = false;
    await media.close();
    audio.dispose();
  });
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  int count(DiagnosticMediaStage stage, DiagnosticResult result) =>
      logs.where((e) => e.media!.stage == stage && e.result == result).length;
  Future<void> connected() async {
    final pending = media.connect(PreviewTranslationSession.ticket);
    await tick();
    socket.wire('app_audio_ready');
    await pending;
  }

  test(
    'socket, ready, merchant and actual first frames remain distinct; muted uplink drops',
    () async {
      final pending = media.connect(PreviewTranslationSession.ticket);
      await tick();
      expect(
        count(DiagnosticMediaStage.connect, DiagnosticResult.succeeded),
        1,
      );
      expect(count(DiagnosticMediaStage.ready, DiagnosticResult.succeeded), 0);
      socket.wire('app_audio_ready', id: 'wrong');
      expect(count(DiagnosticMediaStage.ready, DiagnosticResult.received), 0);
      socket.wire('app_audio_ready');
      socket.wire('app_audio_ready');
      await pending;
      expect(count(DiagnosticMediaStage.ready, DiagnosticResult.received), 1);
      expect(audio.starts, 0);
      await media.setSpeaker(true);
      expect(count(DiagnosticMediaStage.speaker, DiagnosticResult.received), 1);
      socket.wire('merchant_audio_ready');
      socket.wire('merchant_audio_ready');
      await tick();
      expect(audio.speaker, true);
      expect(
        count(DiagnosticMediaStage.merchantReady, DiagnosticResult.received),
        1,
      );
      await media.setMuted(true);
      audio.pcm();
      await tick();
      expect(count(DiagnosticMediaStage.read, DiagnosticResult.received), 1);
      expect(count(DiagnosticMediaStage.send, DiagnosticResult.succeeded), 0);
      expect(socket.sent.where((e) => e['event'] == 'media'), isEmpty);
      await media.setMuted(false);
      for (var i = 1; i <= 3; i++) {
        audio.pcm();
        socket.downlink(sequence: i);
        await tick();
      }
      expect(audio.played.length, 3);
      for (final stage in [
        DiagnosticMediaStage.read,
        DiagnosticMediaStage.send,
        DiagnosticMediaStage.play,
      ]) {
        expect(logs.where((e) => e.media!.stage == stage).length, 1);
      }
      socket.wire(
        'transcript_delta',
        extra: {'segmentId': 's', 'text': 'private-transcript'},
      );
      final text = jsonEncode(logs.map((e) => e.toJson()).toList());
      for (final forbidden in [
        'private-transcript',
        'payload',
        'mock-session',
        'example.invalid',
        'synthetic',
      ]) {
        expect(text, isNot(contains(forbidden)));
      }
    },
  );

  test(
    'playback only succeeds after bridge return; failure does not fake success',
    () async {
      await connected();
      socket.wire('merchant_audio_ready');
      await tick();
      audio.playGate = Completer<void>();
      socket.downlink();
      await tick();
      expect(count(DiagnosticMediaStage.play, DiagnosticResult.succeeded), 0);
      audio.playGate!.completeError(StateError('private-playback-error'));
      await tick();
      expect(count(DiagnosticMediaStage.play, DiagnosticResult.failed), 1);
      expect(count(DiagnosticMediaStage.play, DiagnosticResult.succeeded), 0);
    },
  );

  test(
    'capture routing failure is speaker, not start or cancellation',
    () async {
      await connected();
      audio.failSpeaker = true;
      socket.wire('merchant_audio_ready');
      await tick();
      expect(count(DiagnosticMediaStage.start, DiagnosticResult.succeeded), 1);
      expect(count(DiagnosticMediaStage.speaker, DiagnosticResult.failed), 1);
      expect(count(DiagnosticMediaStage.start, DiagnosticResult.failed), 0);
    },
  );

  test(
    'invalid PCM and failed close remain visible, explicit cleanup can retry',
    () async {
      await connected();
      audio.invalidRead = true;
      audio.failClose = true;
      socket.wire('merchant_audio_ready');
      await tick();
      expect(
        logs.any((e) => e.media!.reason == DiagnosticMediaReason.invalidPcm),
        true,
      );
      expect(count(DiagnosticMediaStage.close, DiagnosticResult.failed), 1);
      expect(count(DiagnosticMediaStage.close, DiagnosticResult.succeeded), 0);
      audio.failClose = false;
      await media.close();
      expect(count(DiagnosticMediaStage.close, DiagnosticResult.succeeded), 1);
    },
  );

  test(
    'transport error keeps its failure category through startup cleanup',
    () async {
      final pending = expectLater(
        media.connect(PreviewTranslationSession.ticket),
        throwsStateError,
      );
      await tick();
      socket.controller.addError(StateError('private-transport'));
      await pending;
      expect(
        logs.any(
          (e) => e.media!.reason == DiagnosticMediaReason.transportError,
        ),
        true,
      );
      expect(count(DiagnosticMediaStage.ready, DiagnosticResult.failed), 1);
      expect(logs.any((e) => e.result == DiagnosticResult.cancelled), false);
    },
  );
}

class _Pcm extends PreviewTranslationPcm {
  bool failSpeaker = false, invalidRead = false;
  @override
  Future<void> setSpeaker(bool enabled) async {
    if (failSpeaker) throw StateError('private-route-error');
    await super.setSpeaker(enabled);
  }

  @override
  Future<Uint8List?> read() =>
      invalidRead ? Future.value(Uint8List(3)) : super.read();
}
