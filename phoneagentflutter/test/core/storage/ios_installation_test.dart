import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/storage/app_local_storage.dart';
import 'package:phone_agent/core/storage/ios_installation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var installed = false, failCommit = false;
  final methods = <String>[];
  const tokenKey = '${IosInstallation.tokenPrefix}synthetic';
  setUp(() {
    installed = false;
    failCommit = false;
    methods.clear();
    FlutterSecureStorage.setMockInitialValues({
      tokenKey: 'synthetic',
      'unrelated-key': 'retained',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
          methods.add(call.method);
          if (call.method == 'installed') return installed;
          if (call.method == 'markInstalled') {
            // Marker is committed only after the scoped token deletion.
            expect(
              await IosInstallation.credentials.read(key: tokenKey),
              isNull,
            );
            if (failCommit) throw PlatformException(code: 'write_failed');
            installed = true;
            return null;
          }
          throw StateError('Unexpected call');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, null),
  );
  test(
    'new installation clears own tokens only and serializes concurrent startup',
    () async {
      final installation = IosInstallation();
      await Future.wait([installation.ensure(), installation.ensure()]);
      expect(methods, ['installed', 'markInstalled']);
      expect(
        await IosInstallation.credentials.read(key: 'unrelated-key'),
        'retained',
      );
      expect(installed, isTrue);
    },
  );
  test(
    'restart and upgrade retain token; simulated reinstall clears it',
    () async {
      installed = true;
      await IosInstallation().ensure();
      expect(
        await IosInstallation.credentials.read(key: tokenKey),
        'synthetic',
      );
      expect(methods, ['installed']);
      installed = false;
      await IosInstallation().ensure();
      expect(await IosInstallation.credentials.read(key: tokenKey), isNull);
    },
  );
  test('failed marker commit is retryable on same initializer', () async {
    final installation = IosInstallation();
    failCommit = true;
    await expectLater(installation.ensure(), throwsA(isA<PlatformException>()));
    expect(installed, isFalse);
    failCommit = false;
    await installation.ensure();
    expect(installed, isTrue);
  });
  test('unavailable marker state never commits or deletes tokens', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, (_) async => null);
    await expectLater(IosInstallation().ensure(), throwsStateError);
    expect(await IosInstallation.credentials.read(key: tokenKey), 'synthetic');
  });
}
