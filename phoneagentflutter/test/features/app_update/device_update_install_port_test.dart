import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/data/device_update_install_port.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/domain/update_install.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ota.test');
  const release = AppUpdateRelease(
    hasUpdate: true,
    packageName: 'com.example.app',
    versionName: '2.0',
    versionCode: 2,
    apkUrl: 'https://objects.example.invalid/a.apk?signature=synthetic',
    downloadHeaders: {'X-Download': 'synthetic'},
  );
  final calls = <MethodCall>[];
  Object? response;
  late DeviceUpdateInstallPort port;
  setUp(() {
    calls.clear();
    response = null;
    port = DeviceUpdateInstallPort(
      scope: 'a' * 64,
      channel: channel,
      web: false,
      platform: TargetPlatform.android,
    );
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
  test('restore sends metadata only, not URL or header credentials', () async {
    expect(await port.restore(release), isNull);
    expect(calls.single.method, 'restore');
    expect(calls.single.arguments.keys, isNot(contains('apkUrl')));
    expect(calls.single.arguments.keys, isNot(contains('downloadHeaders')));
  });
  test(
    'startup peek recovers metadata without persisting or accepting URL/headers',
    () async {
      response = {
        'packageName': 'com.example.app',
        'versionName': '2.0',
        'versionCode': 2,
        'fileSize': 100,
        'checksumSha256': '',
        'forceUpdate': true,
        'releaseNotes': 'Synthetic',
        'apkUrl': 'https://ignored.invalid',
        'downloadHeaders': {'X-Test': 'ignored'},
      };
      final recovered = await port.peek(
        const InstalledApp('com.example.app', '1.0', 1),
      );
      expect(recovered!.forceUpdate, true);
      expect(recovered.apkUrl, isEmpty);
      expect(recovered.downloadHeaders, isEmpty);
      expect(calls.single.method, 'peek');
      expect(calls.single.arguments, {'scope': 'a' * 64});
    },
  );
  test('startup peek validates package version and force fields', () async {
    final valid = {
      'packageName': 'com.example.app',
      'versionName': '2.0',
      'versionCode': 2,
      'fileSize': 100,
      'checksumSha256': '',
      'forceUpdate': true,
      'releaseNotes': 'Synthetic',
    };
    for (final invalid in [
      {...valid, 'packageName': 'com.other.app'},
      {...valid, 'versionCode': 0},
      {...valid, 'forceUpdate': 'yes'},
      {...valid, 'checksumSha256': 'bad'},
    ]) {
      response = invalid;
      await expectLater(
        port.peek(const InstalledApp('com.example.app', '1.0', 1)),
        throwsFormatException,
      );
    }
  });
  test(
    'begin sends only supplied download headers and parses progress',
    () async {
      response = {
        'job': '11111111-1111-4111-8111-111111111111',
        'status': 'downloading',
        'received': 20,
        'total': 100,
      };
      expect((await port.begin(release)).progress, .2);
      expect(calls.single.arguments['downloadHeaders'], {
        'X-Download': 'synthetic',
      });
      expect(calls.single.arguments.keys, isNot(contains('token')));
    },
  );
  for (final current in [45, 2026101513]) {
    test('peek preserves update 45 with installed code $current', () async {
      response = {
        'packageName': 'com.example.app',
        'versionName': '1.0.52',
        'versionCode': 45,
        'fileSize': 100,
        'checksumSha256': '',
        'forceUpdate': false,
        'releaseNotes': '',
      };
      final result = await port.peek(
        InstalledApp('com.example.app', '1.0.52', current),
      );
      expect(result!.versionCode, 45);
    });
  }
  test('malformed snapshot fails closed', () async {
    for (final value in [
      false,
      {},
      {'job': '../x', 'status': 'downloaded', 'received': 1, 'total': 1},
      {
        'job': '11111111-1111-4111-8111-111111111111',
        'status': 'surprise',
        'received': 1,
        'total': 1,
      },
    ]) {
      response = value;
      await expectLater(port.query('job'), throwsFormatException);
    }
  });
  test('malformed permission fails closed', () async {
    response = 'yes';
    await expectLater(port.canInstall(), throwsFormatException);
  });
  test('missing native file is a redownload failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'OTA_FILE_UNAVAILABLE');
        });
    await expectLater(
      port.install('job'),
      throwsA(isA<UpdateDownloadUnavailable>()),
    );
  });
  test(
    'Android system handoff uses scope/job and never an inspection channel',
    () async {
      response = true;
      expect(await port.canInstall(), isTrue);
      response = null;
      await port.openPermission();
      await port.install('job');
      await port.cancel('job');
      expect(calls.map((c) => c.method), [
        'canInstall',
        'permission',
        'install',
        'cancel',
      ]);
      expect(calls.last.arguments, {'scope': 'a' * 64, 'job': 'job'});
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.windows]) {
    test('$platform never calls native update channel', () async {
      final unavailable = DeviceUpdateInstallPort(
        scope: 'a' * 64,
        channel: channel,
        web: false,
        platform: platform,
      );
      await expectLater(
        () => unavailable.begin(release),
        throwsUnsupportedError,
      );
      expect(calls, isEmpty);
    });
  }
  test(
    'Web never calls native channel even for Android target theme',
    () async {
      final unavailable = DeviceUpdateInstallPort(
        scope: 'a' * 64,
        channel: channel,
        web: true,
        platform: TargetPlatform.android,
      );
      await expectLater(
        () => unavailable.restore(release),
        throwsUnsupportedError,
      );
      expect(calls, isEmpty);
    },
  );
}
