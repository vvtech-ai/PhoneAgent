import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/about_providers.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/data/installed_app_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/app_info');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var calls = 0;
  Object? response;
  setUp(() {
    calls = 0;
    response = {
      'packageName': 'com.example.dev',
      'versionName': '1.0-foundation',
      'versionCode': 1,
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      expect(call.method, 'read');
      return response;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  testWidgets(
    'iOS update and about read installed identity and support checks',
    (tester) async {
      const native = MethodChannel('com.vvtech.phone_agent/app_info');
      var nativeReads = 0;
      messenger.setMockMethodCallHandler(native, (call) async {
        nativeReads++;
        expect(call.method, 'read');
        return response;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(native, null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final update = await container.read(installedAppSourceProvider).read();
      expect(update.packageName, 'com.example.dev');
      expect(nativeReads, 1);
      final metadata = await container.read(aboutMetadataSourceProvider).read();
      expect(metadata.versionName, '1.0-foundation');
      expect(nativeReads, 2);
      expect(container.read(startupUpdateSupportedProvider), isTrue);
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
  testWidgets(
    'both mobile platforms read metadata without enabling an installer',
    (tester) async {
      final app = await const InstalledAppChannel(channel: channel).read();
      expect(app.versionName, '1.0-foundation');
      expect(calls, 1);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
  test(
    'reads actual package and version without substituting production identity',
    () async {
      final app = await const InstalledAppChannel(
        channel: channel,
        supported: true,
      ).read();
      expect(app.packageName, 'com.example.dev');
      expect(app.versionName, '1.0-foundation');
      expect(app.versionCode, 1);
      expect(calls, 1);
    },
  );
  test('unsupported platform never invokes native method', () async {
    await expectLater(
      const InstalledAppChannel(channel: channel, supported: false).read(),
      throwsUnsupportedError,
    );
    expect(calls, 0);
  });
  test('malformed metadata fails without guessed version', () async {
    response = {
      'packageName': 'com.example.dev',
      'versionName': '1.0',
      'versionCode': '1',
    };
    await expectLater(
      const InstalledAppChannel(channel: channel, supported: true).read(),
      throwsFormatException,
    );
  });
}
