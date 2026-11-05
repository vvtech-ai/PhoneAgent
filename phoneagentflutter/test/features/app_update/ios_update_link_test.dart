import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/domain/ios_update_link.dart';
import 'package:phone_agent/features/app_update/data/ios_update_link_port.dart';
import 'package:phone_agent/features/app_update/data/secure_startup_update_store.dart';
import 'package:phone_agent/features/app_update/domain/startup_update.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.vvtech.phone_agent/ios_update');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('empty link resolves to user selected App Store', () {
    expect(
      IosUpdateLink.resolve('  '),
      'https://apps.apple.com/app/id6813455647',
    );
  });
  for (final value in [
    'http://apps.apple.com/app/id1',
    'file:///app.ipa',
    'https://user:secret@example.test/update',
    'https://example.test/update.apk',
    'https://example.test/update#fragment',
    'javascript:alert(1)',
  ]) {
    test('rejects invalid distribution link $value', () {
      expect(() => IosUpdateLink.resolve(value), throwsFormatException);
    });
  }
  test(
    'opens validated link and propagates native failure for retry',
    () async {
      final links = <String>[];
      var success = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'open');
        links.add(call.arguments as String);
        return success;
      });
      const port = IosUpdateLinkPort();
      await expectLater(port.open(''), throwsStateError);
      success = true;
      await port.open('itms-apps://apps.apple.com/app/id1');
      expect(links, [
        IosUpdateLink.fallback,
        'itms-apps://apps.apple.com/app/id1',
      ]);
      await expectLater(
        port.open('https://example.test/a.apk'),
        throwsFormatException,
      );
      expect(links, hasLength(2));
    },
  );
  testWidgets(
    'iOS policy lives in sandbox preferences, not Keychain',
    (tester) async {
      const local = MethodChannel('phone_agent/local_storage');
      final values = <String, String>{};
      messenger.setMockMethodCallHandler(local, (call) async {
        final args = call.arguments as Map;
        expect(args['kind'], 'preference');
        final key = args['key'] as String;
        if (call.method == 'write') values[key] = args['value'] as String;
        return call.method == 'read' ? values[key] : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(local, null));
      const store = SecureStartupUpdateStore('test/sdk');
      await store.write(
        startupApp,
        const StartupUpdateRecord(
          lastSuccessDate: '2026-10-20',
          forceRequired: true,
        ),
      );
      final record = await store.read(startupApp);
      expect(record.lastSuccessDate, '2026-10-20');
      expect(record.forceRequired, true);
      expect(values.values.single, isNot(contains('https')));
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
