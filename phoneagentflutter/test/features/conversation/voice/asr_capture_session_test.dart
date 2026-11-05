import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/asr_capture_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_asr_session.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import '../../../core/audio/pcm_capture_fake.dart';
import 'voice_socket_fake.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'pre-ready buffer retains at most two seconds and drains oldest retained frame first',
    () async {
      final socket = VoiceSocketFake();
      final capture = PcmCaptureFake();
      final session = AsrCaptureSession(
        capture: capture,
        asr: TaskAsrSession(connector: (_) async => socket),
      );
      addTearDown(() async {
        capture.frame(null);
        await session.cancel();
      });
      await session.start(Uri.parse('ws://synthetic.invalid/asr'));
      await flush();
      for (var index = 0; index < 101; index++) {
        capture.frame(Uint8List(640)..[0] = index);
        await flush();
      }
      socket.emit('{"type":"ready"}');
      await flush();
      final frames = socket.sent.whereType<Uint8List>().toList();
      expect(frames, hasLength(100));
      expect(frames.first[0], 1);
      expect(frames.last[0], 100);
      capture.frame(Uint8List.fromList([101, 0]));
      await flush();
      expect(socket.sent.whereType<Uint8List>().last, [101, 0]);
    },
  );
  test('release before ASR ready discards locally captured audio', () async {
    final socket = VoiceSocketFake();
    final capture = PcmCaptureFake();
    final session = AsrCaptureSession(
      capture: capture,
      asr: TaskAsrSession(connector: (_) async => socket),
    );
    addTearDown(() async {
      capture.frame(null);
      await session.cancel();
    });
    await session.start(Uri.parse('ws://synthetic.invalid/asr'));
    await flush();
    capture.frame(Uint8List.fromList([1, 2]));
    await flush();
    socket.emit('{"type":"ready"}');
    await session.release();
    await flush();
    expect(capture.starts, 1);
    expect(capture.stops, greaterThanOrEqualTo(1));
    expect(socket.sent.whereType<Uint8List>(), isEmpty);
  });
  test(
    'microphone starts while socket connector is pending; cancel prevents late upload',
    () async {
      final socket = VoiceSocketFake();
      final capture = PcmCaptureFake();
      final connected = Completer<VoiceSocketFake>();
      final session = AsrCaptureSession(
        capture: capture,
        asr: TaskAsrSession(connector: (_) => connected.future),
      );
      addTearDown(() async {
        capture.frame(null);
        await session.cancel();
      });
      final start = session.start(Uri.parse('ws://synthetic.invalid/asr'));
      await flush();
      expect(capture.starts, 1);
      expect(capture.reads, 1);
      await session.cancel();
      connected.complete(socket);
      await start;
      capture.frame(Uint8List.fromList([1, 2]));
      await flush();
      expect(socket.sent.whereType<Uint8List>(), isEmpty);
      expect(socket.closes, 1);
    },
  );
  test(
    'physical hold captures beginning before slow ASR ready, uploads only after ready',
    () async {
      final socket = VoiceSocketFake();
      final capture = PcmCaptureFake();
      final session = AsrCaptureSession(
        capture: capture,
        asr: TaskAsrSession(connector: (_) async => socket),
      );
      final events = <VoiceGatewayEvent>[];
      session.events.listen(events.add);
      addTearDown(() async {
        capture.frame(null);
        await session.cancel();
      });
      await session.start(Uri.parse('ws://synthetic.invalid/asr'));
      await flush();
      expect(capture.starts, 1);
      expect(events.whereType<VoiceReady>(), hasLength(1));
      capture.frame(Uint8List.fromList([1, 2]));
      await flush();
      capture.frame(Uint8List.fromList([3, 4]));
      await flush();
      expect(socket.sent.whereType<Uint8List>(), isEmpty);
      socket.emit('{"type":"ready"}');
      await flush();
      expect(socket.sent.whereType<Uint8List>().map((b) => b.toList()), [
        [1, 2],
        [3, 4],
      ]);
      expect(socket.sent.first as String, contains('start_capture'));
      expect(capture.starts, 1);
      expect(events.whereType<VoiceReady>(), hasLength(1));
    },
  );
  test(
    'pre-ready native failure closes the turn and never uploads buffered audio',
    () async {
      final socket = VoiceSocketFake();
      final capture = PcmCaptureFake()..failStart = true;
      final session = AsrCaptureSession(
        capture: capture,
        asr: TaskAsrSession(connector: (_) async => socket),
      );
      final events = <VoiceGatewayEvent>[];
      session.events.listen(events.add);
      addTearDown(() => session.cancel());
      await session.start(Uri.parse('ws://synthetic.invalid/asr'));
      await flush();
      expect(
        events.whereType<VoiceGatewayFailure>().single.message,
        'capture_failed',
      );
      expect(events.whereType<VoiceReady>(), isEmpty);
      expect(socket.sent.whereType<Uint8List>(), isEmpty);
      expect(capture.stops, greaterThanOrEqualTo(1));
    },
  );
  late VoiceSocketFake socket;
  late PcmCaptureFake capture;
  late AsrCaptureSession session;
  late List<VoiceGatewayEvent> events;
  setUp(() {
    socket = VoiceSocketFake();
    capture = PcmCaptureFake();
    session = AsrCaptureSession(
      capture: capture,
      captureBeforeReady: false, // Preserve the Android production ready gate.
      asr: TaskAsrSession(connector: (_) async => socket),
    );
    events = [];
    session.events.listen(events.add);
  });
  tearDown(() async {
    capture.failStop = false;
    capture.frame(null);
    await session.cancel();
  });
  Future<void> start() =>
      session.start(Uri.parse('ws://synthetic.invalid/asr'));
  Future<void> ready() async {
    socket.emit('{"type":"ready"}');
    await flush();
  }

  test(
    'ready gates native start, PCM uses existing gateway, release preserves one late final',
    () async {
      await start();
      expect(capture.starts, 0);
      await ready();
      expect(capture.starts, 1);
      expect(events.whereType<VoiceReady>().length, 1);
      capture.frame(Uint8List(640));
      await flush();
      expect(socket.sent.whereType<Uint8List>().single.length, 640);
      await session.release();
      capture.frame(Uint8List(640));
      socket.emit('{"type":"partial","text":"ignored"}');
      socket.emit('{"type":"final","text":"accepted"}');
      socket.emit('{"type":"final","text":"duplicate"}');
      await flush();
      expect(socket.sent.whereType<Uint8List>().length, 1);
      expect(events.whereType<VoiceTranscript>().map((e) => e.text), [
        'accepted',
      ]);
    },
  );

  test('release before ready never starts the microphone', () async {
    await start();
    // Queued network ready arrives only after the local release gate closes.
    socket.emit('{"type":"ready"}');
    await session.release();
    await flush();
    expect(capture.starts, 0);
    expect(socket.sent.whereType<Uint8List>(), isEmpty);
  });

  test('cancel during native start drops late ready and PCM', () async {
    capture.startGate = Completer<void>();
    await start();
    await ready();
    await session.cancel();
    capture.startGate!.complete();
    await flush();
    expect(events.whereType<VoiceReady>(), isEmpty);
    expect(capture.reads, 0);
    expect(socket.closes, 1);
  });

  test(
    'native startup failure sanitized, closes socket and releases',
    () async {
      capture.failStart = true;
      await start();
      await ready();
      expect(
        events.whereType<VoiceGatewayFailure>().single.message,
        'capture_failed',
      );
      expect(capture.stops, greaterThanOrEqualTo(1));
      expect(socket.closes, 1);
    },
  );

  test('native interruption cancels rather than restarting capture', () async {
    await start();
    await ready();
    capture.frame(null);
    await flush();
    expect(
      events.whereType<VoiceGatewayFailure>().single.message,
      'capture_interrupted',
    );
    expect(socket.closes, 1);
    expect(capture.starts, 1);
  });

  test('provider failure stops hardware and drops pending read', () async {
    await start();
    await ready();
    socket.emit('{"type":"error","message":"sensitive"}');
    await flush();
    capture.frame(Uint8List(640));
    await flush();
    expect(capture.stops, greaterThanOrEqualTo(1));
    expect(socket.sent.whereType<Uint8List>(), isEmpty);
    expect(
      events.whereType<VoiceGatewayFailure>().first.message,
      'provider_error',
    );
  });

  test('stop failure is surfaced and explicit cancel retries', () async {
    await start();
    await ready();
    capture.failStop = true;
    await expectLater(session.release(), throwsA(anything));
    capture.frame(Uint8List(640));
    await flush();
    expect(socket.sent.whereType<Uint8List>(), isEmpty);
    capture.failStop = false;
    await session.cancel();
    expect(capture.stops, 2);
  });
}
