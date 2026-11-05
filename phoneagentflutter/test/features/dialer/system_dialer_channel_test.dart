import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/data/system_dialer_channel.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/system_dialer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'unsupported platforms and unsafe arguments do not invoke native',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return 'opened';
      });
      const unsupported = SystemDialerChannel(
        channel: channel,
        supported: false,
      );
      expect(await unsupported.open('10086'), SystemDialResult.unsupported);
      const supported = SystemDialerChannel(channel: channel, supported: true);
      for (final number in [
        'tel:10086',
        '10086;123',
        '',
        '+',
        '1+2',
        '10086\n',
      ]) {
        expect(await supported.open(number), SystemDialResult.invalid);
      }
      expect(calls, 0);
    },
  );
  test('native contact targets retain short numbers and star hash', () async {
    final received = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      received.add((call.arguments as Map)['number'] as String);
      return 'opened';
    });
    const port = SystemDialerChannel(channel: channel, supported: true);
    for (final target in ['12', '+123#4', '*123#', '12345678901234567890']) {
      expect(await port.open(target), SystemDialResult.opened);
    }
    expect(received, ['12', '+123#4', '*123#', '12345678901234567890']);
  });
  test('native receives only canonical number and maps outcomes', () async {
    for (final (wire, result) in [
      ('opened', SystemDialResult.opened),
      ('unsupported', SystemDialResult.unsupported),
      ('invalid', SystemDialResult.invalid),
      ('failed', SystemDialResult.failed),
      ('unknown', SystemDialResult.failed),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'open');
        expect(call.arguments, {'number': '+12025550123'});
        return wire;
      });
      expect(
        await const SystemDialerChannel(
          channel: channel,
          supported: true,
        ).open('+12025550123'),
        result,
      );
    }
  });
  test('missing plugin and platform failure are explicit', () async {
    const port = SystemDialerChannel(channel: channel, supported: true);
    expect(await port.open('10086'), SystemDialResult.unsupported);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    expect(await port.open('10086'), SystemDialResult.failed);
  });
}
