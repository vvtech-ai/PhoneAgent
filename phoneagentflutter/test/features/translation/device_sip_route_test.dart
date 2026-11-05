import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/device_sip_route.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/sip_route');
  const lease = SipLease(
    id: 'synthetic',
    accountId: 'synthetic',
    server: 'example.test',
    port: 5060,
    transport: 'UDP',
    username: 'private',
    password: 'private',
    callerNumber: 'synthetic',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform requests route without SIP credentials and preserves resolved peer',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'resolve');
          expect(call.arguments, {'host': 'example.test', 'port': 5060});
          return {'localAddress': '192.0.2.10', 'peerAddress': '198.51.100.20'};
        });
        final route = await DeviceSipRouteResolver(
          platform: platform,
          web: false,
        ).resolve(lease);
        expect(route.localAddress, '192.0.2.10');
        expect(route.peerAddress, '198.51.100.20');
      },
    );
  }
  test(
    'rejects wildcard, multicast and address-family mismatch, no guessing fallback',
    () async {
      for (final result in [
        {'localAddress': '0.0.0.0', 'peerAddress': '198.51.100.20'},
        {'localAddress': '192.0.2.10', 'peerAddress': '::1'},
        {'localAddress': '192.0.2.10', 'peerAddress': '239.1.1.1'},
        {'localAddress': 'invalid', 'peerAddress': '198.51.100.20'},
      ]) {
        messenger.setMockMethodCallHandler(channel, (_) async => result);
        await expectLater(
          const DeviceSipRouteResolver(
            platform: TargetPlatform.android,
            web: false,
          ).resolve(lease),
          throwsA(anything),
        );
      }
    },
  );
  test('web/desktop rejects before native access', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return null;
    });
    await expectLater(
      const DeviceSipRouteResolver(
        platform: TargetPlatform.android,
        web: true,
      ).resolve(lease),
      throwsA(anything),
    );
    await expectLater(
      const DeviceSipRouteResolver(
        platform: TargetPlatform.macOS,
        web: false,
      ).resolve(lease),
      throwsA(anything),
    );
    expect(calls, 0);
  });
}
