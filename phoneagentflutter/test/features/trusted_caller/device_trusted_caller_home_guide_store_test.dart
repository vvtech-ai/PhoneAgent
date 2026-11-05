import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/data/device_trusted_caller_home_guide_store.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/trusted_caller');
  const owner = TrustedCallerOwner('synthetic', 'synthetic', 7);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('display facts carry owner/environment without opening SDK', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'readHomeGuide' ? true : null;
        });
    const store = DeviceTrustedCallerHomeGuideStore('test');
    expect(await store.eligible(owner), true);
    await store.record(owner, disabled: true);
    expect(calls.map((c) => c.method), ['readHomeGuide', 'recordHomeGuide']);
    for (final call in calls) {
      expect(call.arguments['accountId'], owner.accountId);
      expect(call.arguments['loginEpoch'], 7);
      expect(call.arguments['environment'], 'test');
    }
    expect(calls.last.arguments['disabled'], true);
  });
  test('native preference failure propagates for explicit retry', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'SDK_GUIDE_STORE_FAILED');
        });
    expect(
      const DeviceTrustedCallerHomeGuideStore(
        'test',
      ).record(owner, disabled: true),
      throwsA(isA<PlatformException>()),
    );
  });
}
