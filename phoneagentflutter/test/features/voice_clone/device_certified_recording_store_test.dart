import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/device_certified_recording_store.dart';
import 'package:phone_agent/features/voice_clone/domain/certified_recording_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/certified_recording');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform sends typed slot and opaque bytes only', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'read' ? Uint8List.fromList([1, 2]) : null;
      });
      final store = DeviceCertifiedRecordingStore(
        'a' * 64,
        platform: platform,
        web: false,
      );
      await store.replace(Uint8List.fromList([1, 2]));
      expect(await store.read(), [1, 2]);
      await store.clear();
      expect(calls.map((c) => c.method), ['replace', 'read', 'clear']);
      expect((calls.first.arguments as Map).keys, ['slot', 'payload']);
    });
  }
  test(
    'Web does not use native or browser persistence and cannot claim saved',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => fail('Unexpected native call'),
      );
      final store = DeviceCertifiedRecordingStore('b' * 64, web: true);
      expect(await store.read(), isNull);
      await store.clear();
      await expectLater(
        store.replace(Uint8List(1)),
        throwsA(RecordingStoreFailure.unavailable),
      );
    },
  );
  test('arbitrary paths rejected before platform call', () {
    expect(
      () => DeviceCertifiedRecordingStore('../recording'),
      throwsArgumentError,
    );
  });
  test('native corrupt distinct from transient unavailable', () async {
    final store = DeviceCertifiedRecordingStore(
      'a' * 64,
      web: false,
      platform: TargetPlatform.android,
    );
    for (final code in ['recording_corrupt', 'recording_unavailable']) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: code),
      );
      await expectLater(
        store.read(),
        throwsA(
          code == 'recording_corrupt'
              ? RecordingStoreFailure.corrupt
              : RecordingStoreFailure.unavailable,
        ),
      );
    }
  });
}
