import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/pcm_output.dart';
import 'package:phone_agent/features/calls/data/device_call_monitor_output.dart';
import 'package:phone_agent/features/conversation/data/voice/device_pcm_output.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/pcm_output');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late Future<Object?> Function(MethodCall) handler;
  DevicePcmOutput make({bool web = false}) =>
      DevicePcmOutput(channel: channel, platform: TargetPlatform.iOS, web: web);
  setUp(() {
    calls.clear();
    handler = (_) async => true;
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'iOS stop classifies its pending play rejection as cancellation',
    () async {
      final output = make();
      await output.start(24000);
      final pendingPlay = Completer<Object?>();
      final entered = Completer<void>();
      handler = (call) async {
        if (call.method == 'play') {
          entered.complete();
          return pendingPlay.future;
        }
        if (call.method == 'stop') {
          pendingPlay.completeError(
            PlatformException(code: 'output_interrupted'),
          );
        }
        return true;
      };
      final rejected = expectLater(
        output.play(Uint8List(9600)),
        throwsA(
          isA<PcmOutputFailure>().having(
            (e) => e.code,
            'reason',
            'output_cancelled',
          ),
        ),
      );
      await entered.future;
      await output.stop();
      await rejected;
    },
  );
  test(
    'native interruption without a local stop remains a real failure',
    () async {
      final output = make();
      await output.start(24000);
      handler = (call) async {
        if (call.method == 'play') {
          throw PlatformException(code: 'output_interrupted');
        }
        return true;
      };
      await expectLater(
        output.play(Uint8List(9600)),
        throwsA(
          isA<PcmOutputFailure>().having(
            (e) => e.code,
            'reason',
            'output_interrupted',
          ),
        ),
      );
      await output.stop();
    },
  );
  test(
    'a genuine play failure is not hidden by a concurrent local stop',
    () async {
      final output = make();
      await output.start(24000);
      final pendingPlay = Completer<Object?>(), entered = Completer<void>();
      handler = (call) async {
        if (call.method == 'play') {
          entered.complete();
          return pendingPlay.future;
        }
        if (call.method == 'stop') {
          pendingPlay.completeError(
            PlatformException(code: 'output_play_failed'),
          );
        }
        return true;
      };
      final rejected = expectLater(
        output.play(Uint8List(9600)),
        throwsA(
          isA<PcmOutputFailure>().having(
            (e) => e.code,
            'reason',
            'output_play_failed',
          ),
        ),
      );
      await entered.future;
      await output.stop();
      await rejected;
    },
  );
  test('stop rejection retains native failure and remains retryable', () async {
    final output = make();
    await output.start(24000);
    handler = (call) async {
      if (call.method == 'stop') {
        throw PlatformException(code: 'output_interrupted');
      }
      return true;
    };
    await expectLater(
      output.stop(),
      throwsA(
        isA<PcmOutputFailure>().having(
          (e) => e.code,
          'reason',
          'output_interrupted',
        ),
      ),
    );
    handler = (_) async => true;
    await output.stop();
    expect(calls.where((call) => call.method == 'stop'), hasLength(2));
  });
  test(
    'stop cancels pending translation drain with explicit native cancellation',
    () async {
      final output = DevicePcmOutput(
        channel: channel,
        platform: TargetPlatform.android,
        communication: true,
        queuedTranslation: true,
      );
      await output.start(16000);
      final drained = Completer<Object?>(), entered = Completer<void>();
      handler = (call) async {
        if (call.method == 'drain') {
          entered.complete();
          return await drained.future;
        }
        if (call.method == 'stop') {
          drained.completeError(PlatformException(code: 'output_cancelled'));
        }
        return true;
      };
      final rejected = expectLater(
        output.drain(),
        throwsA(
          isA<PcmOutputFailure>().having(
            (e) => e.code,
            'reason',
            'output_cancelled',
          ),
        ),
      );
      await entered.future;
      await output.stop();
      await rejected;
    },
  );
  test(
    'Android translation admits continuous frames and drains actual completion',
    () async {
      final output = DevicePcmOutput(
        channel: channel,
        platform: TargetPlatform.android,
        communication: true,
        queuedTranslation: true,
      );
      await output.start(16000);
      expect(calls.first.arguments['queuedTranslation'], true);
      final drained = Completer<Object?>();
      handler = (call) async =>
          call.method == 'drain' ? await drained.future : true;
      for (var i = 0; i < 20; i++) {
        await output.enqueue(Uint8List(640));
      }
      expect(calls.where((c) => c.method == 'enqueue').length, 20);
      var complete = false;
      final pending = output.drain().then((_) => complete = true);
      await Future<void>.delayed(Duration.zero);
      expect(complete, false);
      drained.complete(true);
      await pending;
      expect(complete, true);
      await output.stop();
      await expectLater(
        output.enqueue(Uint8List(640)),
        throwsA(isA<PcmOutputFailure>()),
      );
    },
  );
  test(
    'translation queue preserves capacity and precise native failure',
    () async {
      final output = DevicePcmOutput(
        channel: channel,
        platform: TargetPlatform.android,
        communication: true,
        queuedTranslation: true,
      );
      await output.start(16000);
      await expectLater(
        output.enqueue(Uint8List(64002)),
        throwsA(isA<PcmOutputFailure>()),
      );
      handler = (call) async {
        if (call.method == 'enqueue') {
          throw PlatformException(code: 'output_stalled');
        }
        return true;
      };
      await expectLater(
        output.enqueue(Uint8List(640)),
        throwsA(
          isA<PcmOutputFailure>().having(
            (e) => e.code,
            'reason',
            'output_stalled',
          ),
        ),
      );
      await output.stop();
    },
  );
  test(
    'iOS translation queues continuously while drain waits for real completion',
    () async {
      final output = DevicePcmOutput(
        channel: channel,
        platform: TargetPlatform.iOS,
        communication: true,
        queuedTranslation: true,
      );
      await output.start(16000);
      expect(calls.first.arguments['queuedTranslation'], true);
      final drained = Completer<Object?>();
      handler = (call) async =>
          call.method == 'drain' ? await drained.future : true;
      await output.enqueue(Uint8List(6400));
      await output.enqueue(Uint8List(6400));
      expect(calls.where((c) => c.method == 'enqueue').length, 2);
      expect(calls.any((c) => c.method == 'play'), false);
      var complete = false;
      final pending = output.drain().then((_) => complete = true);
      await Future<void>.delayed(Duration.zero);
      expect(complete, false);
      drained.complete(true);
      await pending;
      await output.stop();
    },
  );
  test(
    'communication output uses stable identity, local flush and actual route',
    () async {
      final output = DeviceCallMonitorOutput(
        delegate: DevicePcmOutput(
          channel: channel,
          platform: TargetPlatform.android,
          communication: true,
        ),
      );
      await output.start(16000);
      expect((calls.single.arguments as Map)['communication'], true);
      await output.setPlaybackEnabled(false);
      expect(calls.last.method, 'enabled');
      expect((calls.last.arguments as Map)['enabled'], false);
      await output.setPlaybackEnabled(true);
      handler = (call) async => call.method == 'route'
          ? {'selected': 'earpiece', 'bluetooth': false}
          : true;
      final route = await output.route(select: 'speaker');
      // The UI must render native fact, not optimistically display the request.
      expect(route.selected, 'earpiece');
      expect(route.bluetooth, false);
      await output.stop();
      final id = (calls.first.arguments as Map)['outputId'];
      expect(calls.every((c) => (c.arguments as Map)['outputId'] == id), true);
    },
  );
  test(
    'malformed communication route is rejected and TTS never opts in',
    () async {
      final tts = make();
      await tts.start(24000);
      expect(
        (calls.single.arguments as Map).containsKey('communication'),
        false,
      );
      await expectLater(
        tts.communicationRoute(),
        throwsA(isA<PcmOutputFailure>()),
      );
      await expectLater(
        tts.setPlaybackEnabled(false),
        throwsA(isA<PcmOutputFailure>()),
      );
      expect(calls, hasLength(1));
      await tts.stop();
      final output = DeviceCallMonitorOutput(
        delegate: DevicePcmOutput(
          channel: channel,
          platform: TargetPlatform.iOS,
          communication: true,
        ),
      );
      await output.start(16000);
      handler = (_) async => {'selected': 'unknown', 'bluetooth': 'yes'};
      await expectLater(output.route(), throwsA(isA<PcmOutputFailure>()));
      handler = (_) async => true;
      await output.stop();
    },
  );
  test(
    'stable per-output identity and late native played acknowledgement',
    () async {
      final output = make();
      await output.start(24000);
      final consumed = Completer<Object?>();
      handler = (call) async =>
          call.method == 'play' ? await consumed.future : true;
      var played = false;
      final playing = output.play(Uint8List(2)).then((_) => played = true);
      await Future<void>.delayed(Duration.zero);
      expect(played, false);
      consumed.complete(true);
      await playing;
      await output.stop();
      final id = (calls.first.arguments as Map)['outputId'];
      expect(calls.every((c) => (c.arguments as Map)['outputId'] == id), true);
      final other = make();
      await other.start(16000);
      expect((calls.last.arguments as Map)['outputId'], isNot(id));
      await other.stop();
    },
  );
  test('web, invalid format and stop-before-start never call device', () async {
    await expectLater(
      make(web: true).start(24000),
      throwsA(isA<PcmOutputFailure>()),
    );
    await expectLater(make().start(0), throwsA(isA<PcmOutputFailure>()));
    final stopped = make();
    await stopped.stop();
    await expectLater(stopped.start(24000), throwsA(isA<PcmOutputFailure>()));
    expect(calls, isEmpty);
  });
  test('two-second bound and odd PCM reject without a native call', () async {
    final output = make();
    await output.start(8000);
    final gate = Completer<Object?>();
    handler = (c) async => c.method == 'play' ? await gate.future : true;
    final playing = output.play(Uint8List(32000));
    await expectLater(
      output.play(Uint8List(2)),
      throwsA(isA<PcmOutputFailure>()),
    );
    await expectLater(
      output.play(Uint8List(1)),
      throwsA(isA<PcmOutputFailure>()),
    );
    gate.complete(true);
    await playing;
    expect(calls.where((c) => c.method == 'play'), hasLength(1));
    await output.stop();
  });
  test('stop invalidates late start and late consumption', () async {
    for (final stage in ['start', 'play']) {
      final gate = Completer<Object?>();
      handler = (c) async => c.method == stage ? await gate.future : true;
      final output = make();
      if (stage == 'play') await output.start(24000);
      final pending = expectLater(
        stage == 'start' ? output.start(24000) : output.play(Uint8List(2)),
        throwsA(isA<PcmOutputFailure>()),
      );
      await output.stop();
      gate.complete(true);
      await pending;
    }
  });
  test('release errors are scrubbed and explicit stop retries', () async {
    final output = make();
    await output.start(24000);
    handler = (_) async =>
        throw PlatformException(code: 'secret', message: 'private');
    await expectLater(
      output.stop(),
      throwsA(
        isA<PcmOutputFailure>().having(
          (e) => e.toString(),
          'safe',
          isNot(contains('private')),
        ),
      ),
    );
    handler = (_) async => true;
    await output.stop();
    expect(calls.where((c) => c.method == 'stop'), hasLength(2));
  });
}
