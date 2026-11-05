import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/device_translation_call_audio_lease.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('synthetic/call_audio');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'pending cancel waits for native acquire then releases same opaque owner',
    () async {
      final ready = Completer<bool>();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'acquire' ? ready.future : true;
          });
      final lease = DeviceTranslationCallAudioLease(channel: channel);
      final starting = lease.acquire();
      final cancelled = expectLater(starting, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      final ending = lease.release();
      expect(calls.length, 1);
      ready.complete(true);
      await cancelled;
      await ending;
      await lease.release();
      expect(calls.map((v) => v.method), ['acquire', 'release']);
      for (final call in calls) {
        expect((call.arguments as Map)['callAudioId'], lease.id);
      }
      expect(lease.id, matches(RegExp(r'^[a-f0-9]{32}$')));
      await expectLater(lease.acquire(), throwsStateError);
    },
  );
  test(
    'unconfirmed stop retains owner and explicit retry performs cleanup',
    () async {
      var releases = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'release') return ++releases > 1;
            return true;
          });
      final lease = DeviceTranslationCallAudioLease(channel: channel);
      await lease.acquire();
      await expectLater(lease.release(), throwsStateError);
      await lease.release();
      expect(releases, 2);
    },
  );
}
