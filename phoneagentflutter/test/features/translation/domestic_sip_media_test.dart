import 'dart:async';
import 'dart:typed_data';
import 'package:phone_agent/features/translation/domain/sip/translation_intro_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_pcm_bridge.dart';
import 'package:phone_agent/features/translation/domain/translation_realtime_event.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_model_socket.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_model.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_processor.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_sip_media.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_transport.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';

void main() {
  test('iOS preparation leaves business audio idle until start', () async {
    final h = _Harness();
    await h.media.prepare();
    await h.media.prepare();
    expect(h.pcm.prepares, 1);
    expect(h.pcm.resumes, 0);
    expect(h.media.acceptsModelOutput, false);
    expect(h.rtp.sent, isEmpty);
    expect(h.pcm.played, isEmpty);
    expect(h.sockets.expand((s) => s.audio), isEmpty);
    await h.media.start();
    expect(h.pcm.resumes, 1);
    h.pcm.capture.add(Uint8List(640));
    await Future<void>.delayed(Duration.zero);
    expect(h.sockets.first.audio, isNotEmpty);
    await h.media.close();
  });

  test('closing prepared iOS media prevents later audio delivery', () async {
    final h = _Harness();
    await h.media.prepare();
    await h.media.close();
    await expectLater(h.media.start(), throwsA(anything));
    expect(h.pcm.resumes, 0);
    expect(h.pcm.closes, 1);
  });
  test(
    'speaker route is applied after capture starts before any downlink',
    () async {
      final standard = _Harness();
      await standard.media.start();
      expect(standard.pcm.speaker, true);
      await standard.media.close();
      final quiet = _Harness();
      await quiet.media.setSpeaker(false);
      expect(quiet.pcm.routes, isEmpty);
      await quiet.media.start();
      expect(quiet.pcm.routes, [false]);
      await quiet.media.close();
    },
  );
  test(
    'remote model chunk plays continuously without a UI 20ms frame timer',
    () async {
      final h = _Harness();
      expect(h.media.acceptsModelOutput, false);
      await h.media.start();
      final chunk = Uint8List(3200)..fillRange(0, 3200, 3);
      h.sockets[1].events.add(chunk);
      await Future<void>.delayed(Duration.zero);
      expect(h.pcm.played.single.pcm, chunk);
      await h.media.close();
    },
  );
  test(
    'intro suppresses live capture and model output until full Qwen response',
    () async {
      final h = _Harness(intro: _IntroSource());
      final start = h.media.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      h.pcm.capture.add(Uint8List(640)..fillRange(0, 640, 111));
      h.rtp.incoming.add(_packet(1));
      h.sockets[0].events.add(Uint8List(640));
      h.sockets[0].events.add('done');
      await Future<void>.delayed(const Duration(milliseconds: 680));
      expect(h.media.acceptsModelOutput, false);
      expect(h.sockets[0].audio.every((frame) => frame.first != 111), true);
      expect(h.sockets[1].audio, isEmpty);
      h.sockets[0].events.add('responseDone');
      await start;
      expect(h.media.acceptsModelOutput, true);
      await h.media.close();
    },
  );

  test(
    'original mode sends original PCM before any translated output',
    () async {
      final h = _Harness(original: true);
      await h.media.start();
      h.pcm.capture.add(Uint8List(640));
      h.rtp.incoming.add(_packet(1));
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(h.rtp.sent.first.payload.length, 160);
      expect(h.pcm.played.single.pcm.length, 640);
      await h.media.close();
    },
  );

  test(
    'duplex maps local speech to local model, remote RTP to remote model',
    () async {
      final h = _Harness();
      await h.media.start();
      final source = Uint8List.fromList([1, 0, 2, 0]);
      h.pcm.capture.add(source);
      h.rtp.incoming.add(_packet(10));
      h.rtp.incoming.add(_packet(10)); // Duplicate must not translate twice.
      h.rtp.incoming.add(_packet(9)); // Older audio is not replayed.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.sockets[0].audio.single, source);
      expect(h.sockets[1].audio.single.length, 640);
      h.media.setMuted(true);
      h.pcm.capture.add(source);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.sockets[0].audio.last, Uint8List(4));
      await h.media.setSpeaker(true);
      expect(h.pcm.speaker, true);
      await h.media.close();
      await h.media.close();
      expect(h.pcm.closes, 1);
      expect(h.failures, isEmpty);
      expect(h.rtp.closes, 1);
    },
  );
  test(
    'translated local audio becomes 8k RTP and remote becomes device 16k',
    () async {
      final h = _Harness();
      await h.media.start();
      final chunk = Uint8List(640);
      h.sockets[0].events.add(chunk);
      h.sockets[0].events.add('done');
      h.sockets[1].events.add(chunk);
      h.sockets[1].events.add('done');
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(h.rtp.sent.first.payload.length, 160);
      expect(h.rtp.sent.first.payloadType, 8);
      expect(h.pcm.played.single.sampleRate, 16000);
      expect(h.pcm.played.single.pcm.length, 640);
      await h.media.close();
      final count = h.rtp.sent.length;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(h.rtp.sent.length, count);
    },
  );
  test(
    'negotiated DTMF uses RTP terminal repetitions; INFO only without negotiation',
    () async {
      final h = _Harness();
      await h.media.start();
      var info = 0;
      await h.media.sendDtmf(
        '#',
        sendInfo: (_) async {
          info++;
        },
      );
      expect(info, 0);
      expect(h.rtp.sent.length, 10);
      expect(h.rtp.sent.every((packet) => packet.payloadType == 101), true);
      expect(
        h.rtp.sent.skip(7).every((packet) => packet.payload[1] & 0x80 != 0),
        true,
      );
      await h.media.close();
      final fallback = _Harness(telephoneEvent: null);
      await fallback.media.start();
      await fallback.media.sendDtmf(
        '1',
        sendInfo: (_) async {
          info++;
        },
      );
      expect(info, 1);
      expect(fallback.rtp.sent, isEmpty);
      await fallback.media.close();
    },
  );
  test('model failure stops all owners and does not replay capture', () async {
    final h = _Harness();
    await h.media.start();
    h.sockets[0].events.add('failed');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(h.failures, ['MODEL_SERVICE_ERROR']);
    expect(h.pcm.closes, 1);
    expect(h.rtp.closes, 1);
    expect(h.sockets.map((socket) => socket.closes), [1, 1]);
    await h.media.close();
  });
}

SipRtpPacket _packet(int sequence) => SipRtpPacket(
  payloadType: 8,
  sequence: sequence,
  timestamp: 160,
  ssrc: 17,
  payload: Uint8List(160)..fillRange(0, 160, 0xd5),
);

class _Harness {
  _Harness({
    int? telephoneEvent = 101,
    bool original = false,
    TranslationIntroAudioSource? intro,
  }) {
    var index = 0;
    final models = DomesticTranslationProcessor(
      local: _Protocol(),
      remote: _Protocol(),
      connect: (_, _) async => sockets[index++],
      isCurrent: () => true,
      onEvent: (direction, event) => media.onModelEvent(direction, event),
    );
    media = DomesticSipMedia(
      pcm: pcm,
      models: models,
      rtp: rtp,
      endpoint: SipAudioEndpoint(
        '127.0.0.1',
        9000,
        8,
        SipAudioCodec.pcma,
        telephoneEvent,
      ),
      isCurrent: () => true,
      onFailure: failures.add,
      ssrc: 33,
      originalAudioEnabled: original,
      introSource: intro,
    );
  }
  final pcm = _Pcm();
  final rtp = _Rtp();
  final sockets = [_Socket(), _Socket()];
  final failures = <String>[];
  late final DomesticSipMedia media;
}

class _Pcm implements TranslationPcmBridge, TranslationPcmPreparation {
  _Pcm() {
    iterator = StreamIterator(capture.stream);
  }
  final capture = StreamController<Uint8List>();
  late final StreamIterator<Uint8List> iterator;
  final played = <TranslationAudio>[];
  bool speaker = false;
  bool started = false;
  final routes = <bool>[];
  int closes = 0;
  int prepares = 0, resumes = 0;
  @override
  Future<void> prepareCallAudio() async {
    prepares++;
    started = true;
  }

  @override
  Future<void> start() async {
    resumes++;
    started = true;
  }

  @override
  Future<Uint8List?> read() async =>
      await iterator.moveNext() ? iterator.current : null;
  @override
  Future<void> play(TranslationAudio audio) async {
    played.add(audio);
  }

  @override
  Future<void> setSpeaker(bool value) async {
    if (!started) throw StateError('capture not started');
    routes.add(value);
    speaker = value;
  }

  @override
  Future<void> close() async {
    closes++;
    await iterator.cancel();
    unawaited(capture.close());
  }
}

class _Rtp implements SipRtpTransport {
  final incoming = StreamController<SipRtpPacket>();
  final sent = <SipRtpPacket>[];
  int closes = 0;
  @override
  Stream<SipRtpPacket> get packets => incoming.stream;
  @override
  void send(SipRtpPacket packet) {
    sent.add(packet);
  }

  @override
  Future<void> close() async {
    closes++;
    unawaited(incoming.close());
  }
}

class _Socket implements DomesticModelSocket {
  final events = StreamController<Object>();
  final audio = <Uint8List>[];
  int closes = 0;
  @override
  Stream<Object> get messages => events.stream;
  @override
  void send(Object event) {
    if (event == 'start') {
      events.add('ready');
    }
    if (event is Uint8List) {
      audio.add(event);
    }
  }

  @override
  Future<void> close() async {
    closes++;
    unawaited(events.close());
  }
}

class _Protocol implements DomesticModelProtocol {
  @override
  Uri get uri => Uri.parse('wss://example.test');
  @override
  Map<String, String> get headers => {'Authorization': 'synthetic'};
  @override
  Object start() => 'start';
  @override
  Object finish() => 'finish';
  @override
  Object audio(Uint8List pcm16k) => pcm16k;
  @override
  List<DomesticModelEvent> decode(Object message) => switch (message) {
    'ready' => [const DomesticModelReady()],
    'done' => [const DomesticModelAudioDone()],
    'responseDone' => [const DomesticModelResponseDone()],
    'failed' => [const DomesticModelError('MODEL_SERVICE_ERROR')],
    Uint8List bytes => [DomesticModelAudio(bytes)],
    _ => [],
  };
}

class _IntroSource implements TranslationIntroAudioSource {
  @override
  Future<List<Uint8List>> load(String language) async => [Uint8List(640)];
  @override
  Future<List<Uint8List>> trigger() async => [
    Uint8List(640)..fillRange(0, 640, 3),
  ];
}
