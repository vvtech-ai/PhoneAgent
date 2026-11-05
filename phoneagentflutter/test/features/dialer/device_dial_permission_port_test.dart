import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/data/device_dial_permission_port.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/dial-permission');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  String? response;
  setUp(() {
    calls.clear();
    response = 'granted';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return response;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'Android status is read-only; requests target exact permissions',
    () async {
      const port = DeviceDialPermissionPort(
        channel: channel,
        platform: TargetPlatform.android,
        web: false,
      );
      expect(await port.location(), DialPermissionGrant.granted);
      await port.location(request: true);
      await port.callLog();
      await port.callLog(request: true);
      expect(calls.map((c) => c.method), [
        'locationStatus',
        'resolve',
        'resolve',
        'resolve',
      ]);
      expect(calls.first.arguments, isNull);
      expect(calls[1].arguments, {'permission': 'location', 'request': true});
      expect(calls[2].arguments, {'permission': 'callLog', 'request': false});
      expect(calls[3].arguments, {'permission': 'callLog', 'request': true});
    },
  );
  test('iOS never requests system call log', () async {
    const port = DeviceDialPermissionPort(
      channel: channel,
      platform: TargetPlatform.iOS,
      web: false,
    );
    expect(port.supportsCallLog, isFalse);
    expect(await port.callLog(request: true), DialPermissionGrant.unavailable);
    expect(calls, isEmpty);
    response = 'blocked';
    expect(await port.location(), DialPermissionGrant.blocked);
  });
  test('Web does not invoke native channel', () async {
    const port = DeviceDialPermissionPort(
      channel: channel,
      platform: TargetPlatform.android,
      web: true,
    );
    expect(await port.location(request: true), DialPermissionGrant.unavailable);
    expect(await port.callLog(request: true), DialPermissionGrant.unavailable);
    expect(calls, isEmpty);
  });
  test('malformed permission response fails, never fabricates grant', () async {
    const port = DeviceDialPermissionPort(
      channel: channel,
      platform: TargetPlatform.android,
      web: false,
    );
    response = 'unknown';
    await expectLater(port.location(), throwsFormatException);
    await expectLater(port.callLog(), throwsFormatException);
  });
  test('missing plugin reports unavailable', () async {
    messenger.setMockMethodCallHandler(channel, null);
    const port = DeviceDialPermissionPort(
      channel: channel,
      platform: TargetPlatform.android,
      web: false,
    );
    expect(await port.location(), DialPermissionGrant.unavailable);
  });
}
