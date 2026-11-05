import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/data/device_network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/network_availability');
  const source = DeviceNetworkAvailability();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('strict response mapping and no account/device input', () async {
    for (final item in <(Object?, NetworkAvailability)>[
      ('available', NetworkAvailability.available),
      ('unavailable', NetworkAvailability.unavailable),
      ('unknown', NetworkAvailability.unknown),
      (true, NetworkAvailability.unknown),
      (null, NetworkAvailability.unknown),
      ({'online': true}, NetworkAvailability.unknown),
      ('ONLINE', NetworkAvailability.unknown),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'read');
        expect(call.arguments, isNull);
        return item.$1;
      });
      expect(await source.read(), item.$2);
    }
  });

  test('missing plugin and platform error are unknown', () async {
    expect(await source.read(), NetworkAvailability.unknown);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'sample_failed'),
    );
    expect(await source.read(), NetworkAvailability.unknown);
    expect(
      await const UnknownNetworkAvailability().read(),
      NetworkAvailability.unknown,
    );
  });
}
