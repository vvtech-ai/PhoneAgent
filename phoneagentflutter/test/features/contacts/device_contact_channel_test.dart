import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/device_contact_channel.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('synthetic/contacts');
  final calls = <MethodCall>[];
  Object? response;
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return response;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  const source = DeviceContactChannel(channel: channel, supported: true);
  test(
    'unsupported Web never invokes a native channel or fakes permission',
    () async {
      expect(
        (await const DeviceContactChannel(
          channel: channel,
          supported: false,
        ).load(requestPermission: true)).access,
        ContactAccess.unsupported,
      );
      expect(calls, isEmpty);
    },
  );
  test(
    'permission request is explicit; denied result discards any stray rows',
    () async {
      response = {
        'access': 'denied',
        'rows': [
          {'name': '不可显示', 'phone': '13800000000'},
        ],
      };
      expect((await source.load()).rows, isEmpty);
      expect(calls.single.arguments, {'requestPermission': false});
      await source.load(requestPermission: true);
      expect(calls.last.arguments, {'requestPermission': true});
    },
  );
  test('authorized and limited rows use the same shared contract', () async {
    for (final access in ['authorized', 'limited']) {
      response = {
        'access': access,
        'rows': [
          {
            'name': '合成',
            'phone': '13800000000',
            'normalizedPhone': '+8613800000000',
            'label': '自定义标签',
          },
        ],
      };
      final data = await source.load();
      expect(data.canRead, isTrue);
      expect(data.rows.single.normalizedPhone, '+8613800000000');
      expect(data.rows.single.label, '自定义标签');
    }
  });
  test(
    'malformed permission and contact rows are failures, not empty success',
    () async {
      response = {'access': 'future'};
      await expectLater(source.load(), throwsFormatException);
      response = {
        'access': 'authorized',
        'rows': [
          {'name': '合成', 'phone': 123},
        ],
      };
      await expectLater(source.load(), throwsFormatException);
    },
  );
}
