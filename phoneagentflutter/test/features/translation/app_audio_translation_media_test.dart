import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket_io.dart';
import 'package:phone_agent/features/translation/data/app_audio_translation_media.dart';
import 'package:phone_agent/features/translation/data/preview_app_audio_ports.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/domain/translation_realtime_event.dart';
import '../conversation/voice/voice_input_fake.dart';

void main() {
  late PreviewAppAudioSocket socket;
  late PreviewTranslationPcm audio;
  late AudioPlaybackFocus focus;
  late AppAudioTranslationMedia media;
  late List<Object> errors;
  late List<TranslationRealtimeMessage> events;
  bool current = true;
  setUp(() {
    current = true;
    socket = PreviewAppAudioSocket();
    audio = PreviewTranslationPcm();
    focus = AudioPlaybackFocus();
    errors = [];
    events = [];
    media = AppAudioTranslationMedia(
      connector: (_) async => socket,
      audio: audio,
      permissions: InputPermissionFake(),
      focus: focus,
      isCurrent: () => current,
    );
    media.events.listen(events.add, onError: errors.add);
  });
  tearDown(() async {
    audio.failClose = false;
    await media.close();
  });
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  Future<void> ready() async {
    final pending = media.connect(PreviewTranslationSession.ticket);
    await tick();
    socket.wire('app_audio_ready');
    await pending;
  }

  test(
    'URL preserves grants and explicit downlink query; rejects unsafe endpoints',
    () {
      final uri = AppAudioTranslationMedia.endpoint(
        'wss://example.invalid/audio?ticket=a%2Bb',
      );
      expect(uri.queryParameters, {'ticket': 'a+b', 'downlinkAudio': 'binary'});
      expect(
        AppAudioTranslationMedia.endpoint(
          'wss://example.invalid/audio?downlinkAudio=json',
        ).queryParameters['downlinkAudio'],
        'json',
      );
      for (final value in [
        'ws://example.invalid/a',
        'wss://user:secret@example.invalid/a',
        'wss://example.invalid/a#x',
      ]) {
        expect(
          () => AppAudioTranslationMedia.endpoint(value),
          throwsStateError,
        );
      }
    },
  );
  test(
    'open and other ready events never open app gate or start microphone',
    () async {
      bool connected = false;
      final pending = media
          .connect(PreviewTranslationSession.ticket)
          .then((_) => connected = true);
      await tick();
      expect(socket.sent.single['protocolVersion'], 'java-v1');
      expect(socket.sent.single['sampleRate'], 16000);
      socket.wire('worker_ready');
      socket.wire('realtime_ready');
      socket.wire('app_audio_ready', id: 'other');
      await tick();
      expect(connected, false);
      expect(audio.starts, 0);
      socket.wire('app_audio_ready', id: '');
      await pending;
      expect(audio.starts, 0);
      socket.wire('call_connected');
      socket.downlink();
      await tick();
      expect(audio.starts, 0);
      expect(audio.played, isEmpty);
      socket.wire('merchant_audio_ready');
      socket.wire('merchant_audio_ready');
      await tick();
      expect(audio.starts, 1);
      expect(audio.speaker, false);
    },
  );
  test(
    'mute drops uplink while downlink continues; resume sends only new frames',
    () async {
      await ready();
      socket.wire('merchant_audio_ready');
      await tick();
      audio.pcm();
      await tick();
      expect(socket.sent.where((m) => m['event'] == 'media'), hasLength(1));
      await media.setMuted(true);
      audio.pcm();
      socket.downlink();
      await tick();
      expect(socket.sent.where((m) => m['event'] == 'media'), hasLength(1));
      expect(audio.played, hasLength(1));
      await media.setMuted(false);
      audio.pcm();
      await tick();
      expect(socket.sent.where((m) => m['event'] == 'media'), hasLength(2));
      expect(
        base64Decode(socket.sent.last['payload'] as String),
        Uint8List.fromList(List.filled(640, 1)),
      );
      expect(media.supportsDtmf, false);
      await expectLater(media.sendDtmf('1'), throwsUnsupportedError);
      expect(socket.sent.any((m) => m['event'] == 'dtmf_digit'), false);
    },
  );
  test(
    'sequence dedupe, independent sample rates and negative sequences',
    () async {
      await ready();
      socket.wire('merchant_audio_ready');
      await tick();
      for (final sequence in [2, 2, 1, -1, -1, 3]) {
        socket.downlink(
          sequence: sequence,
          rate: sequence == 3 ? 16000 : 24000,
        );
      }
      await tick();
      expect(audio.played.map((a) => a.sequence), [2, -1, -1, 3]);
      expect(audio.played.last.sampleRate, 16000);
      expect(errors, isEmpty);
    },
  );
  test('bounded downlink fails and stops actual resources', () async {
    await ready();
    socket.wire('merchant_audio_ready');
    await tick();
    audio.playGate = Completer<void>();
    for (var i = 0; i < 202; i++) {
      socket.downlink(sequence: i);
    }
    await tick();
    expect(errors, hasLength(1));
    expect(audio.closed, true);
    expect(socket.closed, true);
    expect(focus.active, isNull);
    audio.playGate!.complete();
  });
  test('late capture start after close cannot send or retain focus', () async {
    await ready();
    audio.startGate = Completer<void>();
    socket.wire('merchant_audio_ready');
    await tick();
    await media.close();
    audio.startGate!.complete();
    await tick();
    expect(audio.started, false);
    expect(focus.active, isNull);
    expect(socket.sent.where((m) => m['event'] == 'media'), isEmpty);
  });
  test(
    'stop sends stop once, invalidates pending read and retains failed lease',
    () async {
      await ready();
      socket.wire('merchant_audio_ready');
      await tick();
      audio.failClose = true;
      await expectLater(media.close(), throwsStateError);
      expect(focus.active?.owner, 'translation-app-audio');
      audio.failClose = false;
      await media.close();
      await media.close();
      expect(focus.active, isNull);
      expect(socket.sent.where((m) => m['event'] == 'stop'), hasLength(1));
    },
  );
  test(
    'terminal and native output failure stop without automatic restart',
    () async {
      await ready();
      socket.wire('merchant_audio_ready');
      await tick();
      audio.failPlay = true;
      socket.downlink();
      await tick();
      expect(errors, hasLength(1));
      expect(audio.closed, true);
      socket.wire('merchant_audio_ready');
      await tick();
      expect(audio.starts, 1);
    },
  );
  test('late socket after cancellation is closed before start frame', () async {
    final gate = Completer<VoiceSocket>();
    final pendingMedia = AppAudioTranslationMedia(
      connector: (_) => gate.future,
      audio: audio,
      permissions: InputPermissionFake(),
      focus: focus,
      isCurrent: () => current,
    );
    final pending = expectLater(
      pendingMedia.connect(PreviewTranslationSession.ticket),
      throwsStateError,
    );
    await tick();
    await pendingMedia.close();
    gate.complete(socket);
    await pending;
    expect(socket.closed, true);
    expect(socket.sent, isEmpty);
    expect(focus.active, isNull);
  });
  test('account invalidation prevents next captured frame upload', () async {
    await ready();
    socket.wire('merchant_audio_ready');
    await tick();
    current = false;
    audio.pcm();
    await tick();
    await media.close();
    expect(socket.sent.where((m) => m['event'] == 'media'), isEmpty);
    expect(focus.active, isNull);
  });
  test('actual IO loopback start/media/binary translated/stop wire', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = <Map<String, dynamic>>[];
    final stopReceived = Completer<void>();
    final peer = Completer<WebSocket>();
    server.listen((request) async {
      expect(request.uri.queryParameters['downlinkAudio'], 'binary');
      final ws = await WebSocketTransformer.upgrade(request);
      peer.complete(ws);
      ws.listen((data) {
        final frame = jsonDecode(data as String) as Map<String, dynamic>;
        received.add(frame);
        if (frame['event'] == 'stop' && !stopReceived.isCompleted) {
          stopReceived.complete();
        }
        if (frame['type'] == 'start') {
          ws.add('{"event":"app_audio_ready","callSessionId":"mock-session"}');
          ws.add(
            '{"event":"merchant_audio_ready","callSessionId":"mock-session"}',
          );
        }
      });
    });
    final ioMedia = AppAudioTranslationMedia(
      connector: (uri) => connectVoiceSocket(
        uri.replace(scheme: 'ws', host: '127.0.0.1', port: server.port),
      ),
      audio: audio,
      permissions: InputPermissionFake(),
      focus: focus,
      isCurrent: () => current,
    );
    ioMedia.events.listen((_) {}, onError: errors.add);
    try {
      await ioMedia.connect(PreviewTranslationSession.ticket);
      for (var i = 0; i < 20 && !audio.started; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      audio.pcm();
      final header = utf8.encode(
        '{"event":"translated_audio","sampleRate":24000,"sequence":1}',
      );
      final binary = Uint8List(4 + header.length + 480);
      ByteData.sublistView(binary).setUint32(0, header.length, Endian.big);
      binary.setRange(4, 4 + header.length, header);
      (await peer.future).add(binary);
      for (
        var i = 0;
        i < 20 && (audio.played.isEmpty || received.length < 2);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(audio.played.single.pcm.length, 480);
      expect(received.last['event'], 'media');
      await ioMedia.close();
      await stopReceived.future.timeout(const Duration(seconds: 2));
      expect(received.last['event'], 'stop');
    } finally {
      await ioMedia.close();
      await server.close(force: true);
    }
  });
}
