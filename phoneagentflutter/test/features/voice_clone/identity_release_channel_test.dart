import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/device_identity_capture_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/identity_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform waits for native release after acknowledged abort',
      () async {
        final released = Completer<void>();
        final sessions = <String>{};
        messenger.setMockMethodCallHandler(channel, (call) async {
          sessions.add((call.arguments as Map)['session'] as String);
          if (call.method == 'prepare') return 'synthetic';
          if (call.method == 'waitForRelease') await released.future;
          return null;
        });
        final port = DeviceIdentityCapturePort(web: false, platform: platform);
        await port.prepare();
        await port.abort();
        var completed = false;
        final waiting = port.waitForRelease().then((_) => completed = true);
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        released.complete();
        await waiting;
        expect(sessions.length, 1);
      },
    );
  }
  test('unused or unsupported release wait never invokes SDK', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return null;
    });
    for (final web in [true, false]) {
      final port = DeviceIdentityCapturePort(
        web: web,
        platform: TargetPlatform.iOS,
      );
      await port.abort();
      await port.waitForRelease();
    }
    expect(calls, 0);
  });
  test(
    'abort failure is retryable and concurrent abort remains single flight',
    () async {
      var aborts = 0;
      final retry = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepare') return 'synthetic';
        if (call.method == 'abort') {
          aborts++;
          if (aborts == 1) {
            throw PlatformException(code: 'capture_release_failed');
          }
          await retry.future;
        }
        return null;
      });
      final port = DeviceIdentityCapturePort(
        web: false,
        platform: TargetPlatform.android,
      );
      await port.prepare();
      await expectLater(
        port.abort(),
        throwsA(IdentityCaptureFailure.unavailable),
      );
      final a = port.abort(), b = port.abort();
      await Future<void>.delayed(Duration.zero);
      expect(aborts, 2);
      retry.complete();
      await Future.wait([a, b]);
      await port.abort();
      expect(aborts, 2);
    },
  );
  test(
    'missing release implementation cannot pretend hardware is free',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepare') return 'synthetic';
        throw MissingPluginException();
      });
      final port = DeviceIdentityCapturePort(
        web: false,
        platform: TargetPlatform.iOS,
      );
      await port.prepare();
      await expectLater(
        port.waitForRelease(),
        throwsA(IdentityCaptureFailure.unavailable),
      );
    },
  );
}
