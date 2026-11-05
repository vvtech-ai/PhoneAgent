import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/recording/device_domestic_recording_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/domestic_recording');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'both device platforms use only explicit private paths and await completion',
    () async {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'directory' ? '/private/synthetic' : null;
        });
        const encoder = DeviceDomesticRecordingEncoder();
        expect(await encoder.privateRoot(), '/private/synthetic');
        await encoder.encode(
          pcmPath: '/private/synthetic/mix.pcm16',
          m4aPath: '/private/synthetic/recording.m4a',
        );
        expect(calls.last.arguments, {
          'pcmPath': '/private/synthetic/mix.pcm16',
          'm4aPath': '/private/synthetic/recording.m4a',
        });
      }
    },
  );
  test(
    'missing private path and native encoding errors remain failures',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'directory') {
          return 'relative';
        }
        throw PlatformException(code: 'recording_encode_failed');
      });
      const encoder = DeviceDomesticRecordingEncoder();
      await expectLater(encoder.privateRoot(), throwsStateError);
      await expectLater(
        encoder.encode(pcmPath: 'a', m4aPath: 'b'),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
