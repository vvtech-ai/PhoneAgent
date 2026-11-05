import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/context/device_agent_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/agent_location');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('Web returns no coordinates and never touches platform', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) => throw StateError('No native access'),
    );
    expect(await DeviceAgentLocation(web: true).read(), isNull);
  });
  test(
    'read has only request identity, matching cancel and no permission request',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'read'
            ? {'lat': 22.5, 'lng': 114, 'address': '合成地址'}
            : null;
      });
      final result = await DeviceAgentLocation(
        web: false,
        platform: TargetPlatform.android,
      ).read();
      expect(result?.display, '合成地址');
      expect(calls.map((c) => c.method), ['read', 'cancel']);
      expect(calls.first.arguments, calls.last.arguments);
      expect((calls.first.arguments as Map).keys, ['requestId']);
    },
  );
  test(
    'null and invalid platform values cannot become a fake success',
    () async {
      Object? value;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'read' ? value : null,
      );
      final source = DeviceAgentLocation(
        web: false,
        platform: TargetPlatform.iOS,
      );
      expect(await source.read(), isNull);
      for (value in [
        {'lat': '22', 'lng': 114},
        {'lat': 22, 'lng': 181},
        {'lat': 22, 'lng': 114, 'address': 123},
      ]) {
        await expectLater(source.read(), throwsFormatException);
      }
    },
  );
}
