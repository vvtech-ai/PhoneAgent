import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/data/device_call_log_channel.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('synthetic/call-log');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Object? response;
  setUp(() {
    calls.clear();
    response = {'access': 'ready', 'rows': []};
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return response;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  const source = DeviceCallLogChannel(channel: channel, supported: true);
  Map<String, Object?> row(
    String id, {
    String phone = '+12025550101',
    int time = 1,
  }) => {
    'id': id,
    'phone': phone,
    'name': ' Synthetic ',
    'startedAtMillis': time,
  };

  test('iOS does not invoke system call-log channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      (await const DeviceCallLogChannel(channel: channel).load()).access,
      DialRecentAccess.unsupported,
    );
    expect(calls, isEmpty);
  });
  test('unsupported platforms never invoke channel', () async {
    expect(
      (await const DeviceCallLogChannel(
        channel: channel,
        supported: false,
      ).load()).access,
      DialRecentAccess.unsupported,
    );
    expect(calls, isEmpty);
  });
  for (final access in ['denied', 'failed']) {
    test('$access drops any attached records without exposing data', () async {
      response = {
        'access': access,
        'rows': [row('sensitive')],
      };
      final result = await source.load();
      expect(result.access.name, access);
      expect(result.records, isEmpty);
      expect(calls.single.method, 'load');
      expect(calls.single.arguments, isNull);
    });
  }
  test(
    'ready maps system identities, trims, filters private numbers and caps20',
    () async {
      response = {
        'access': 'ready',
        'rows': [
          row('unknown', phone: '-1', time: 100),
          row('private', phone: '-2', time: 100),
          row('blank', phone: ' ', time: 100),
          for (var i = 0; i < 25; i++)
            row('$i', phone: ' +12025550101 ', time: i),
          row('24', time: 24),
        ],
      };
      final result = await source.load();
      expect(result.access, DialRecentAccess.ready);
      expect(result.records, hasLength(20));
      expect(result.records.first.id, '24');
      expect(result.records.last.id, '5');
      expect(result.records.first.name, 'Synthetic');
      expect(result.records.first.phone, '+12025550101');
      expect(
        result.records.every(
          (r) =>
              r.source == DialRecentSource.system &&
              r.kind == DialRecentKind.normal,
        ),
        isTrue,
      );
    },
  );
  test('empty ready is distinct from invalid provider response', () async {
    expect((await source.load()).records, isEmpty);
    for (final value in [
      null,
      {'access': 'unknown'},
      {'access': 'ready'},
      {
        'access': 'ready',
        'rows': [row('')],
      },
      {
        'access': 'ready',
        'rows': [
          {...row('id'), 'startedAtMillis': 'bad'},
        ],
      },
    ]) {
      response = value;
      await expectLater(source.load(), throwsFormatException);
    }
  });
  test(
    'platform error propagates to controller failure, no retry or permission request',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        throw PlatformException(code: 'read_failed');
      });
      await expectLater(source.load(), throwsA(isA<PlatformException>()));
      expect(calls, hasLength(1));
      expect(calls.single.method, 'load');
    },
  );
}
