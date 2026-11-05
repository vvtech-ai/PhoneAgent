import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/contact_authorization_channel.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('synthetic/contact-entry');
  const port = ContactAuthorizationChannel(channel: channel);
  Object? response;
  final calls = <MethodCall>[];
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
  test(
    'check and request are permission-only separate explicit methods',
    () async {
      response = {
        'access': 'denied',
        'canRequest': true,
        'rows': 'never consumed',
      };
      expect((await port.check()).access, ContactAccess.denied);
      expect((await port.request()).canRequest, isTrue);
      expect(calls.map((c) => c.method), [
        'authorization',
        'requestAuthorization',
      ]);
      expect(calls.every((c) => c.arguments == null), isTrue);
    },
  );
  test('limited allowed and denied request eligibility retained', () async {
    response = {'access': 'limited', 'canRequest': false};
    expect((await port.check()).canRead, isTrue);
    response = {'access': 'denied', 'canRequest': false};
    expect((await port.check()).canRequest, isFalse);
  });
  test('unknown permission or missing eligibility is an error', () async {
    response = {'access': 'future', 'canRequest': true};
    await expectLater(port.check(), throwsFormatException);
    response = {'access': 'denied'};
    await expectLater(port.check(), throwsFormatException);
  });
}
