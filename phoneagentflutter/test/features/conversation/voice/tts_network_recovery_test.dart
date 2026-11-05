import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/conversation/data/voice/conversation_tts_stream.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../../core/audio/pcm_output_fake.dart';
import 'voice_socket_fake.dart';

void main() {
  for (final cancel in [false, true]) {
    test(
      'late connection cannot revive replaced or cancelled request: $cancel',
      () {
        fakeAsync((clock) {
          final pending = Completer<VoiceSocketFake>();
          final old = VoiceSocketFake();
          final replacement = VoiceSocketFake();
          var connects = 0;
          final session = TaskTtsSession(
            connector: (_) {
              connects++;
              return connects == 1 ? pending.future : Future.value(replacement);
            },
          );
          final events = <VoiceGatewayEvent>[];
          session.events.listen(events.add);
          session.start(
            Uri.parse('ws://synthetic.invalid'),
            text: '第一句',
            speaker: 'synthetic',
          );
          clock.flushMicrotasks();
          session.setNetworkAvailable(false);
          if (cancel) session.cancel();
          session.setNetworkAvailable(true);
          clock.flushMicrotasks();
          pending.complete(old);
          clock.flushMicrotasks();
          expect(old.closes, 1);
          expect(old.sent, isEmpty);
          if (!cancel) {
            replacement.emit('{"type":"ready"}');
            replacement.emit(Uint8List(2));
            replacement.emit('{"type":"complete"}');
            clock.flushMicrotasks();
            expect(events.whereType<VoicePcmChunk>(), hasLength(1));
            expect(events.whereType<VoiceGatewayFailure>(), isEmpty);
          } else {
            expect(events, isEmpty);
            expect(connects, 1);
          }
          session.cancel();
          clock.flushMicrotasks();
          expect(clock.nonPeriodicTimerCount, 0);
          expect(clock.periodicTimerCount, 0);
        });
      },
    );
  }
  late StreamController<NetworkAvailability> network;
  late ConversationTtsStream stream;
  late List<VoiceSocketFake> sockets;
  late PcmOutputFake output;
  late List<DiagnosticEvent> diagnostics;
  void setup({Future<String>? speaker}) {
    network = StreamController<NetworkAvailability>.broadcast(sync: true);
    sockets = [];
    diagnostics = [];
    output = PcmOutputFake();
    stream = ConversationTtsStream(
      endpoint: Uri.parse('ws://synthetic.invalid/tts'),
      output: output,
      focus: AudioPlaybackFocus(),
      isCurrent: () => true,
      onChanged: () {},
      networkEvents: network.stream,
      speaker: speaker,
      createSession: () => TaskTtsSession(
        diagnostics: MediaDiagnostics(
          diagnostics.add,
          DiagnosticMediaComponent.taskTts,
        ),
        connector: (_) async {
          final socket = VoiceSocketFake(closeMessagesOnClose: false);
          sockets.add(socket);
          return socket;
        },
      ),
    );
  }

  void dispose(FakeAsync clock) {
    stream.cancel();
    network.close();
    for (final socket in sockets) {
      socket.input.close();
    }
    clock.flushMicrotasks();
    expect(clock.nonPeriodicTimerCount, 0);
    expect(clock.periodicTimerCount, 0);
  }

  List<String> requests() => sockets
      .expand((s) => s.sent)
      .whereType<String>()
      .map(jsonDecode)
      .where((v) => v['type'] == 'synthesize')
      .map((v) => v['text'] as String)
      .toList();

  test(
    'offline deadline during speaker lookup counts failure and cannot start later',
    () {
      fakeAsync((clock) {
        final speaker = Completer<String>();
        setup(speaker: speaker.future);
        stream.enqueue('第一句');
        clock.flushMicrotasks();
        network.add(NetworkAvailability.unavailable);
        clock.elapse(const Duration(seconds: 15));
        clock.flushMicrotasks();
        expect(stream.phase, ReplySpeechPhase.failed);
        expect(stream.failures, 1);
        speaker.complete('synthetic');
        network.add(NetworkAvailability.available);
        clock.flushMicrotasks();
        expect(sockets, isEmpty);
        dispose(clock);
      });
    },
  );

  test(
    'buffered but undelivered PCM can retry once without duplicate audio',
    () {
      fakeAsync((clock) {
        setup();
        network.add(NetworkAvailability.available);
        stream.enqueue('第一句');
        stream.complete();
        clock.flushMicrotasks();
        sockets[0].emit('{"type":"ready"}');
        sockets[0].emit(Uint8List(2));
        clock.flushMicrotasks();
        expect(stream.queuedBytes, 0);
        network.add(NetworkAvailability.unavailable);
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 6));
        expect(stream.failures, 0);
        expect(sockets, hasLength(1));
        network.add(NetworkAvailability.available);
        clock.flushMicrotasks();
        sockets[0].emit(Uint8List(24000));
        sockets[0].emit('{"type":"complete"}');
        sockets[1].emit('{"type":"ready"}');
        sockets[1].emit(Uint8List(4));
        sockets[1].emit('{"type":"complete"}');
        clock.flushMicrotasks();
        expect(stream.queuedBytes, 15360 + 4 + 2880);
        expect(stream.failures, 0);
        expect(requests(), ['第一句', '第一句']);
        final pause = diagnostics.singleWhere(
          (e) =>
              e.media?.stage == DiagnosticMediaStage.close &&
              e.media?.reason == DiagnosticMediaReason.networkChanged,
        );
        expect(pause.media!.audioBytes, 2);
        expect(pause.media!.requestSent, isTrue);
        final reconnect = diagnostics.firstWhere(
          (e) => e.media?.stage == DiagnosticMediaStage.reconnect,
        );
        expect(reconnect.media!.attempt, 2);
        final receiveIds = diagnostics
            .where((e) => e.media?.stage == DiagnosticMediaStage.receive)
            .map((e) => e.media!.requestId)
            .toSet();
        expect(receiveIds, hasLength(2));
        expect(
          jsonEncode(diagnostics.map((e) => e.toJson()).toList()),
          isNot(contains('第一句')),
        );
        dispose(clock);
      });
    },
  );

  test('second network loss cannot exceed the one-replacement budget', () {
    fakeAsync((clock) {
      setup();
      network.add(NetworkAvailability.available);
      stream.enqueue('第一句');
      clock.flushMicrotasks();
      for (var i = 0; i < 2; i++) {
        network.add(NetworkAvailability.unavailable);
        clock.flushMicrotasks();
        network.add(NetworkAvailability.available);
        clock.flushMicrotasks();
      }
      expect(sockets, hasLength(2));
      expect(stream.failures, 1);
      expect(stream.synthesizing, isFalse);
      dispose(clock);
    });
  });

  test('active offline timeout preserves failure and releases all timers', () {
    fakeAsync((clock) {
      setup();
      network.add(NetworkAvailability.available);
      stream.enqueue('第一句');
      stream.enqueue('第二句');
      clock.flushMicrotasks();
      network.add(NetworkAvailability.unavailable);
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 15));
      clock.flushMicrotasks();
      expect(stream.phase, ReplySpeechPhase.failed);
      expect(stream.failures, 1);
      network.add(NetworkAvailability.available);
      clock.flushMicrotasks();
      expect(sockets, hasLength(1));
      dispose(clock);
    });
  });

  test('initial offline holds queued text and resumes both sentences', () {
    fakeAsync((clock) {
      setup();
      network.add(NetworkAvailability.unavailable);
      stream.enqueue('第一句');
      stream.enqueue('第二句');
      stream.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 4));
      expect(sockets, isEmpty);
      expect(stream.hasPendingText, isTrue);
      network.add(NetworkAvailability.available);
      clock.flushMicrotasks();
      final socket = sockets.single;
      socket.emit('{"type":"ready"}');
      socket.emit(Uint8List(2));
      socket.emit('{"type":"complete"}');
      clock.flushMicrotasks();
      socket.emit(Uint8List(2));
      socket.emit('{"type":"complete"}');
      clock.flushMicrotasks();
      expect(requests(), ['第一句', '第二句']);
      expect(stream.failures, 0);
      dispose(clock);
    });
  });
  test('partial audio is never replayed and offline queue resumes online', () {
    fakeAsync((clock) {
      setup();
      network.add(NetworkAvailability.available);
      stream.enqueue('第一句');
      stream.enqueue('第二句');
      stream.complete();
      clock.flushMicrotasks();
      sockets[0].emit('{"type":"ready"}');
      sockets[0].emit(Uint8List(24000));
      clock.flushMicrotasks();
      network.add(NetworkAvailability.unavailable);
      clock.flushMicrotasks();
      expect(stream.failures, 1);
      expect(sockets, hasLength(1));
      expect(stream.hasPendingText, isTrue);
      network.add(NetworkAvailability.available);
      clock.flushMicrotasks();
      sockets[0].emit(Uint8List(24000));
      sockets[0].emit('{"type":"complete"}');
      sockets[1].emit('{"type":"ready"}');
      sockets[1].emit(Uint8List(2));
      sockets[1].emit('{"type":"complete"}');
      clock.flushMicrotasks();
      expect(requests(), ['第一句', '第二句']);
      expect(stream.queuedBytes, 15360 + 24000 + 2 + 2880);
      dispose(clock);
    });
  });
  test(
    'offline deadline fails once and online cannot revive cancelled queue',
    () {
      fakeAsync((clock) {
        setup();
        network.add(NetworkAvailability.unavailable);
        stream.enqueue('第一句');
        stream.enqueue('第二句');
        stream.complete();
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 15));
        clock.flushMicrotasks();
        expect(stream.phase, ReplySpeechPhase.failed);
        expect(stream.hasPendingText, isFalse);
        network.add(NetworkAvailability.available);
        clock.flushMicrotasks();
        expect(sockets, isEmpty);
        dispose(clock);
      });
    },
  );
  test('cancel while offline prevents reconnection', () {
    fakeAsync((clock) {
      setup();
      network.add(NetworkAvailability.available);
      stream.enqueue('第一句');
      clock.flushMicrotasks();
      network.add(NetworkAvailability.unavailable);
      clock.flushMicrotasks();
      stream.cancel();
      clock.flushMicrotasks();
      network.add(NetworkAvailability.available);
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 20));
      expect(sockets, hasLength(1));
      expect(requests(), isEmpty);
      dispose(clock);
    });
  });
  test('transport failure after delivered PCM never retries the sentence', () {
    fakeAsync((clock) {
      setup();
      stream.enqueue('第一句');
      stream.enqueue('第二句');
      clock.flushMicrotasks();
      sockets[0].emit('{"type":"ready"}');
      sockets[0].emit(Uint8List(24000));
      clock.flushMicrotasks();
      sockets[0].input.addError(StateError('synthetic disconnect'));
      clock.flushMicrotasks();
      sockets[1].emit('{"type":"ready"}');
      clock.flushMicrotasks();
      expect(requests(), ['第一句', '第二句']);
      expect(stream.failures, 1);
      dispose(clock);
    });
  });
}
