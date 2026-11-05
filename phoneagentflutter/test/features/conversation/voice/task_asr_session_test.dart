import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/task_asr_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_voice_endpoint.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'voice_socket_fake.dart';

final endpoint = Uri.parse(
  'ws://localhost/aiassistant-api/ws/assistant/task-voice/asr',
);
void main() {
  test('endpoint preserves context and v65 language normalization', () {
    for (final language in ['en', 'EN-us', 'jp', 'ja-JP', 'unknown']) {
      final uri = TaskVoiceEndpoint.asr(
        Uri.parse('https://example.test/aiassistant-api/'),
        language,
      );
      expect(uri.scheme, 'wss');
      expect(uri.path, '/aiassistant-api/ws/assistant/task-voice/asr');
      expect(
        uri.queryParameters['languageCode'],
        language.toLowerCase().startsWith('en')
            ? 'en-US'
            : language == 'unknown'
            ? 'zh-CN'
            : 'ja-JP',
      );
    }
    for (final base in [
      'file:///path',
      'https://a:b@example.test/',
      'https://example.test/?token=private',
      'https://example.test/#private',
    ]) {
      expect(() => TaskVoiceEndpoint.tts(Uri.parse(base)), throwsArgumentError);
    }
  });
  test(
    'ready controls PCM and release admits only one nonempty late final',
    () {
      fakeAsync((clock) {
        final socket = VoiceSocketFake();
        final session = TaskAsrSession(connector: (_) async => socket);
        final events = <VoiceGatewayEvent>[];
        session.events.listen(events.add);
        session.start(endpoint);
        clock.flushMicrotasks();
        expect(session.sendPcm(Uint8List(640)), isFalse);
        socket.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        socket.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        expect(socket.sent.whereType<String>().map(jsonDecode).toList(), [
          {'type': 'start_capture', 'mode': 'open_listening'},
        ]);
        expect(session.sendPcm(Uint8List(640)), isTrue);
        socket.emit('{"type":"final","text":"first"}');
        socket.emit('{"type":"final","text":"second"}');
        clock.flushMicrotasks();
        session.release();
        expect(session.sendPcm(Uint8List(2)), isFalse);
        for (final frame in [
          '{"type":"partial","text":"drop"}',
          '{"type":"final","text":" "}',
          '{"type":"final","text":"late"}',
          '{"type":"final","text":"drop"}',
        ]) {
          socket.emit(frame);
        }
        clock.flushMicrotasks();
        expect(events.whereType<VoiceTranscript>().map((e) => e.text), [
          'first',
          'second',
          'late',
        ]);
        expect(
          jsonDecode(socket.sent.whereType<String>().last)['type'],
          'stop_capture',
        );
        clock.elapse(const Duration(seconds: 90));
        clock.flushMicrotasks();
        expect(socket.closes, 1);
        expect(events.last, isA<VoiceTransportClosed>());
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );
  test('release during connect closes late socket without start_capture', () {
    fakeAsync((clock) {
      final pending = Completer<VoiceSocketFake>();
      final session = TaskAsrSession(connector: (_) => pending.future);
      session.events.listen((_) {});
      session.start(endpoint);
      session.release();
      clock.flushMicrotasks();
      final socket = VoiceSocketFake();
      pending.complete(socket);
      clock.flushMicrotasks();
      expect(socket.sent, isEmpty);
      expect(socket.closes, 1);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });
  test('ready deadline sanitizes failure and closes a late connection', () {
    fakeAsync((clock) {
      final pending = Completer<VoiceSocketFake>();
      final events = <VoiceGatewayEvent>[];
      final session = TaskAsrSession(connector: (_) => pending.future);
      session.events.listen(events.add);
      session.start(endpoint);
      clock.elapse(const Duration(seconds: 10));
      clock.flushMicrotasks();
      expect(
        events.whereType<VoiceGatewayFailure>().single.message,
        'ready_timeout',
      );
      final socket = VoiceSocketFake();
      pending.complete(socket);
      clock.flushMicrotasks();
      expect(socket.closes, 1);
      expect(socket.sent, isEmpty);
    });
  });
  test('cancelled old connection cannot send text into new session', () {
    fakeAsync((clock) {
      final old = VoiceSocketFake(), next = VoiceSocketFake();
      final a = TaskAsrSession(connector: (_) async => old),
          b = TaskAsrSession(connector: (_) async => next);
      final events = <VoiceGatewayEvent>[];
      a.events.listen((_) {});
      b.events.listen(events.add);
      a.start(endpoint);
      b.start(endpoint);
      clock.flushMicrotasks();
      old.emit('{"type":"ready"}');
      next.emit('{"type":"ready"}');
      clock.flushMicrotasks();
      old.emit('{"type":"final","text":"old"}');
      a.cancel();
      next.emit('{"type":"final","text":"current"}');
      clock.flushMicrotasks();
      expect(events.whereType<VoiceTranscript>().single.text, 'current');
      b.cancel();
      clock.flushMicrotasks();
    });
  });
  for (final message in [
    'private broken payload',
    '{"type":"error","message":"private reason"}',
    Uint8List(2),
  ]) {
    test(
      'malformed/provider/binary frame fails without raw payload $message',
      () {
        fakeAsync((clock) {
          final socket = VoiceSocketFake();
          final session = TaskAsrSession(connector: (_) async => socket);
          final failures = <VoiceGatewayFailure>[];
          session.events.listen((e) {
            if (e is VoiceGatewayFailure) failures.add(e);
          });
          session.start(endpoint);
          clock.flushMicrotasks();
          socket.emit(message);
          clock.flushMicrotasks();
          expect(failures.length, 1);
          expect(failures.single.message, isNot(contains('private')));
          expect(socket.closes, 1);
        });
      },
    );
  }
  test('invalid PCM fails instead of silent truncation', () {
    fakeAsync((clock) {
      final socket = VoiceSocketFake();
      final session = TaskAsrSession(connector: (_) async => socket);
      session.events.listen((_) {});
      session.start(endpoint);
      clock.flushMicrotasks();
      socket.emit('{"type":"ready"}');
      clock.flushMicrotasks();
      expect(session.sendPcm(Uint8List(641)), isFalse);
      clock.flushMicrotasks();
      expect(socket.closes, 1);
    });
  });
}
