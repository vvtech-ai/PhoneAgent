import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/context/device_agent_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/device_clock');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'native clock reads without arguments and does not cache zone',
    () async {
      var zone = 'Asia/Shanghai';
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'read');
        expect(call.arguments, isNull);
        return {
          'epochMillis': 1700000000000,
          'offsetSeconds': 28800,
          'timezone': zone,
        };
      });
      const source = DeviceAgentClock(
        platform: TargetPlatform.android,
        web: false,
      );
      expect((await source.read()).timezone, 'Asia/Shanghai');
      zone = 'Asia/Taipei';
      expect((await source.read()).timezone, zone);
    },
  );
  test('malformed native snapshot fails explicitly', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'epochMillis': 'wrong'},
    );
    await expectLater(
      const DeviceAgentClock(platform: TargetPlatform.iOS, web: false).read(),
      throwsFormatException,
    );
  });
  test('web and unsupported platform never call native channel', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => fail('Unexpected native read'),
    );
    expect(
      (await const DeviceAgentClock(web: true).read()).epochMillis,
      greaterThan(0),
    );
    expect(
      (await const DeviceAgentClock(
        web: false,
        platform: TargetPlatform.windows,
      ).read()).timezone,
      matches(r'^[+-]\d\d:\d\d'),
    );
  });
}
