import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/fallback_voice_input_session.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_input_session.dart';

class InputFake implements VoiceInputSession {
  final stream = StreamController<VoiceGatewayEvent>.broadcast(sync: true);
  Completer<void>? stopGate;
  int starts = 0, stops = 0;
  bool failStop = false;
  Uri? endpoint;
  @override
  Stream<VoiceGatewayEvent> get events => stream.stream;
  void emit(VoiceGatewayEvent event) => stream.add(event);
  @override
  Future<void> start(Uri uri) async {
    starts++;
    endpoint = uri;
  }

  @override
  Future<void> release() async {
    stops++;
  }

  @override
  Future<void> cancel() async {
    stops++;
    await stopGate?.future;
    if (failStop) throw StateError('private native detail');
  }
}

void main() {
  final primaryUri = Uri.parse('ws://synthetic.invalid/asr');
  final fallbackUri = Uri.parse('ws://synthetic.invalid/transcription');
  late InputFake primary, fallback;
  late FallbackVoiceInputSession session;
  late List<VoiceGatewayEvent> events;
  late bool current;
  late int created;
  setUp(() {
    primary = InputFake();
    fallback = InputFake();
    events = [];
    current = true;
    created = 0;
    session = FallbackVoiceInputSession(
      primary: primary,
      createFallback: () {
        created++;
        return fallback;
      },
      fallbackEndpoint: fallbackUri,
      isCurrent: () => current,
    );
    session.events.listen(events.add);
  });
  tearDown(() async {
    primary.failStop = false;
    if (primary.stopGate?.isCompleted == false) primary.stopGate!.complete();
    await session.cancel();
    await primary.stream.close();
    await fallback.stream.close();
  });

  for (final reason in [
    'provider_error',
    'connect_failed',
    'transport_error',
    'send_failed',
    'ready_timeout',
    'invalid_frame',
  ]) {
    test('one fallback for $reason, second failure terminal', () async {
      await session.start(primaryUri);
      primary.emit(VoiceGatewayFailure(reason));
      await Future<void>.delayed(Duration.zero);
      expect(primary.stops, 1);
      expect(created, 1);
      expect(fallback.endpoint, fallbackUri);
      expect(events.single, isA<VoiceRecognitionFallback>());
      primary.emit(const VoiceTranscript('stale', isFinal: true));
      fallback.emit(const VoiceTranscript('current', isFinal: true));
      fallback.emit(const VoiceGatewayFailure('provider_error'));
      fallback.emit(const VoiceTranscript('after failure', isFinal: true));
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<VoiceTranscript>().single.text, 'current');
      expect(events.whereType<VoiceGatewayFailure>().length, 1);
      expect(created, 1);
    });
  }
  for (final event in [
    const VoiceTransportClosed('provider_closed'),
    const VoiceGatewayFailure('provider_closed'),
    const VoiceGatewayFailure('capture_failed'),
    const VoiceGatewayFailure('capture_interrupted'),
    const VoiceGatewayFailure('capture_stop_failed'),
    const VoiceGatewayFailure('invalid_pcm'),
  ]) {
    test(
      'no fallback for ${event.runtimeType} ${event is VoiceGatewayFailure ? event.message : ''}',
      () async {
        await session.start(primaryUri);
        primary.emit(event);
        await Future<void>.delayed(Duration.zero);
        expect(created, 0);
        expect(events.single, same(event));
      },
    );
  }
  for (final abort in ['cancel', 'release', 'stale']) {
    test(
      'waits for actual stop; $abort prevents late fallback creation',
      () async {
        primary.stopGate = Completer<void>();
        await session.start(primaryUri);
        primary.emit(const VoiceGatewayFailure('provider_error'));
        await Future<void>.delayed(Duration.zero);
        expect(created, 0);
        if (abort == 'cancel') session.cancel();
        if (abort == 'release') session.release();
        if (abort == 'stale') current = false;
        await Future<void>.delayed(Duration.zero);
        primary.stopGate!.complete();
        await Future<void>.delayed(Duration.zero);
        expect(created, 0);
        expect(primary.stops, 1);
      },
    );
  }
  test(
    'stop failure prevents competing capture and remains retryable',
    () async {
      primary.failStop = true;
      await session.start(primaryUri);
      primary.emit(const VoiceGatewayFailure('provider_error'));
      await Future<void>.delayed(Duration.zero);
      expect(created, 0);
      expect(
        events.whereType<VoiceGatewayFailure>().single.message,
        'fallback_start_or_cleanup_failed',
      );
      primary.failStop = false;
      await session.cancel();
      expect(primary.stops, 2);
    },
  );
  test(
    'explicit release disables subsequent retry while keeping late final',
    () async {
      await session.start(primaryUri);
      await session.release();
      primary.emit(const VoiceTranscript('tail', isFinal: true));
      primary.emit(const VoiceGatewayFailure('provider_error'));
      expect(events.whereType<VoiceTranscript>().single.text, 'tail');
      expect(created, 0);
    },
  );
}
