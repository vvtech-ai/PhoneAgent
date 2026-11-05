import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/device_environment.dart';
import 'package:phone_agent/features/app_logs/data/device_environment_channel.dart';
import 'package:phone_agent/features/app_logs/domain/format_device_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/device_environment');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var response = <String, Object?>{};
  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readEnvironment');
      return response;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  Map<String, Object?> native() {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return {
      'appVersionName': '1.8.0',
      'appVersionCode': 52,
      'osName': ios ? 'iOS' : 'Android',
      'osVersion': ios ? '18.0' : '15',
      if (!ios) 'apiLevel': 35,
      'deviceBrand': ios ? 'Apple' : 'google',
      'deviceManufacturer': ios ? 'Apple' : 'Google',
      'deviceModel': ios ? 'iPhone' : 'Pixel 9',
      'deviceHardwareModel': ios ? 'iPhone17,3' : 'tokay',
      'serialNumber': 'must-not-be-exported',
      'deviceName': 'personal-name',
    };
  }

  const platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });
  testWidgets(
    'both platforms use actual native fields and export only diagnostic fields',
    (_) async {
      response = native();
      final environment = await const DeviceEnvironmentChannel(
        channel: channel,
      ).read();
      final json = environment.toJson();
      expect(json['appVersion'], '1.8.0');
      expect(json['appBuild'], 52);
      expect(
        json['osVersion'],
        defaultTargetPlatform == TargetPlatform.iOS ? '18.0' : '15',
      );
      expect(
        json['hardwareModel'],
        defaultTargetPlatform == TargetPlatform.iOS ? 'iPhone17,3' : 'tokay',
      );
      expect(json.toString(), isNot(contains('personal-name')));
      expect(json.toString(), isNot(contains('must-not-be-exported')));
      expect(formatDeviceEnvironment(environment), contains('hardware='));
    },
    variant: platforms,
  );
  testWidgets(
    'missing or malformed metadata is rejected rather than using a guessed version',
    (_) async {
      for (final entry in <String, Object?>{
        'appVersionCode': '52',
        'deviceModel': '',
        'osVersion': null,
      }.entries) {
        response = native()..[entry.key] = entry.value;
        await expectLater(
          const DeviceEnvironmentChannel(channel: channel).read(),
          throwsFormatException,
        );
      }
    },
    variant: platforms,
  );
  test(
    'summary preserves Unicode boundaries, removes control characters and fits both API columns',
    () {
      final value = DeviceEnvironment(
        appVersion: '😀' * 200,
        appBuild: 9223372036854775807,
        osName: 'Android',
        osVersion: '系统\n版本' * 50,
        apiLevel: 35,
        brand: '厂商\t' * 50,
        manufacturer: '品牌' * 100,
        model: '😀' * 100,
        hardwareModel: '设备' * 100,
      );
      final summary = formatDeviceEnvironment(value);
      expect(summary.length, lessThanOrEqualTo(512));
      expect(summary, isNot(contains('\n')));
      expect(summary, isNot(contains('\t')));
      expect(summary, isNot(contains('\uFFFD')));
    },
  );
}
