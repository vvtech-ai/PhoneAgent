import 'dart:convert';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'voice_socket_fake.dart';

class _LateSocket extends VoiceSocketFake {
  @override
  Future<void> close() async {
    closes++;
  }
}

final endpoint = Uri.parse(
  'wss://example.test/tts?token=SECRET&scope=a&scope=b',
);
void main() {
  for (final ready in [false, true]) {
    test('timeout retains ready=$ready and actual send state', () {
      fakeAsync((clock) {
        final events = <DiagnosticEvent>[];
        final socket = _LateSocket();
        late Uri opened;
        final session = TaskTtsSession(
          maxRecoveryRetries: 0,
          connector: (uri) async {
            opened = uri;
            return socket;
          },
          diagnostics: MediaDiagnostics(
            events.add,
            DiagnosticMediaComponent.taskTts,
            traceId: '11111111-1111-4111-8111-111111111111',
          ),
        );
        session.events.listen((_) {});
        session.start(
          endpoint,
          text: 'PRIVATE TEXT',
          speaker: 'PRIVATE SPEAKER',
        );
        clock.flushMicrotasks();
        if (ready) {
          socket.emit('{"type":"ready"}');
          clock.flushMicrotasks();
        }
        clock.elapse(Duration(seconds: ready ? 5 : 15));
        clock.flushMicrotasks();
        final failure = events.singleWhere(
          (e) =>
              e.media!.reason ==
              (ready
                  ? DiagnosticMediaReason.firstAudioTimeout
                  : DiagnosticMediaReason.completionTimeout),
        );
        final copy = DiagnosticEvent.fromJson(
          jsonDecode(jsonEncode(failure.toJson())),
        );
        expect(copy.media!.requestId, opened.queryParameters['mediaRequestId']);
        expect(copy.media!.requestId, isNotEmpty);
        expect(copy.media!.attempt, 1);
        expect(copy.media!.ready, ready);
        expect(copy.media!.requestSent, ready);
        expect(copy.media!.audioBytes, 0);
        expect(
          events
              .where((e) => e.media!.stage == DiagnosticMediaStage.send)
              .length,
          ready ? 1 : 0,
        );
        expect(opened.queryParametersAll['scope'], ['a', 'b']);
        expect(opened.queryParameters['token'], 'SECRET');
        expect(
          jsonEncode(events.map((e) => e.toJson()).toList()),
          isNot(matches('PRIVATE|SECRET|example.test')),
        );
        expect(clock.nonPeriodicTimerCount, 0);
      });
    });
  }

  test(
    'empty retry uses fresh ID; old audio never becomes new attempt first audio',
    () {
      fakeAsync((clock) {
        final events = <DiagnosticEvent>[];
        final sockets = <VoiceSocketFake>[];
        final ids = <String>[];
        final session = TaskTtsSession(
          connector: (uri) async {
            ids.add(uri.queryParameters['mediaRequestId']!);
            final socket = _LateSocket();
            sockets.add(socket);
            return socket;
          },
          diagnostics: MediaDiagnostics(
            events.add,
            DiagnosticMediaComponent.taskTts,
          ),
        );
        session.events.listen((_) {});
        session.start(endpoint, text: 'PRIVATE', speaker: 'PRIVATE');
        clock.flushMicrotasks();
        sockets[0].emit('{"type":"ready"}');
        clock.flushMicrotasks();
        sockets[0].emit('{"type":"complete"}');
        clock.flushMicrotasks();
        expect(ids.toSet().length, 2);
        sockets[0].emit(Uint8List(100));
        clock.flushMicrotasks();
        sockets[1].emit('{"type":"ready"}');
        clock.flushMicrotasks();
        for (var i = 0; i < 20; i++) {
          sockets[1].emit(Uint8List(2));
        }
        clock.flushMicrotasks();
        final audio = events.singleWhere(
          (e) => e.media!.stage == DiagnosticMediaStage.receive,
        );
        expect(audio.media!.requestId, ids[1]);
        expect(audio.media!.attempt, 2);
        session.cancel();
        clock.flushMicrotasks();
        final cancelled = events.singleWhere(
          (e) =>
              e.media!.stage == DiagnosticMediaStage.complete &&
              e.result == DiagnosticResult.cancelled,
        );
        expect(cancelled.media!.audioBytes, 40);
        expect(cancelled.media!.requestId, ids[1]);
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );
}
