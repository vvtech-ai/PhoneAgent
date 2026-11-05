import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/device_pcm_capture.dart';
import 'package:phone_agent/core/audio/pcm_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/pcm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late Future<Object?> Function(MethodCall) handler;
  DevicePcmCapture make({bool web = false}) => DevicePcmCapture(
    channel: channel,
    platform: TargetPlatform.android,
    web: web,
  );
  setUp(() {
    calls.clear();
    handler = (call) async => call.method == 'read' ? Uint8List(640) : true;
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'single-use id, PCM and idempotent stop; distinct turns have distinct ids',
    () async {
      final first = make();
      await first.start();
      expect((await first.read())!.length, 640);
      await first.stop();
      await first.stop();
      expect(await first.read(), isNull);
      expect(calls.map((e) => e.method), ['start', 'read', 'stop']);
      final id = (calls.first.arguments as Map)['captureId'];
      expect(
        calls.every((e) => (e.arguments as Map)['captureId'] == id),
        isTrue,
      );
      await expectLater(first.start(), throwsA(isA<PcmCaptureFailure>()));
      final second = make();
      await second.start();
      expect((calls.last.arguments as Map)['captureId'], isNot(id));
      await second.stop();
    },
  );

  test('web and stop before start never invoke native', () async {
    final web = make(web: true);
    await expectLater(web.start(), throwsA(isA<PcmCaptureFailure>()));
    await web.stop();
    final stopped = make();
    await stopped.stop();
    await expectLater(stopped.start(), throwsA(isA<PcmCaptureFailure>()));
    expect(calls, isEmpty);
  });

  test('only one read, stopped late PCM is discarded', () async {
    final gate = Completer<Object?>();
    handler = (call) async => call.method == 'read' ? await gate.future : true;
    final capture = make();
    await capture.start();
    final read = capture.read();
    await expectLater(capture.read(), throwsA(isA<PcmCaptureFailure>()));
    await capture.stop();
    gate.complete(Uint8List(640));
    expect(await read, isNull);
  });

  test('cancel while starting does not acknowledge capture ready', () async {
    final gate = Completer<Object?>();
    handler = (call) async => call.method == 'start' ? await gate.future : true;
    final capture = make();
    final start = expectLater(
      capture.start(),
      throwsA(isA<PcmCaptureFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    await capture.stop();
    gate.complete(true);
    await start;
  });

  test('native stop failure is sanitized and retryable', () async {
    var stopCount = 0;
    handler = (call) async {
      if (call.method == 'stop' && ++stopCount == 1) {
        throw PlatformException(
          code: 'secret_native_detail',
          message: 'token=secret',
        );
      }
      return true;
    };
    final capture = make();
    await capture.start();
    await expectLater(
      capture.stop(),
      throwsA(
        isA<PcmCaptureFailure>().having(
          (e) => e.toString(),
          'safe',
          'PcmCaptureFailure(capture_failed)',
        ),
      ),
    );
    await capture.stop();
    expect(stopCount, 2);
  });

  for (final bad in [Uint8List(0), Uint8List(1), Uint8List(642), 'not PCM']) {
    test(
      'malformed PCM ${bad.runtimeType}/${bad is Uint8List ? bad.length : 0}',
      () async {
        handler = (call) async => call.method == 'read' ? bad : true;
        final capture = make();
        await capture.start();
        await expectLater(capture.read(), throwsA(isA<PcmCaptureFailure>()));
        await capture.stop();
      },
    );
  }
}
