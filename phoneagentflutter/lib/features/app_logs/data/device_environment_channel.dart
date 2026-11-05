import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/diagnostics/device_environment.dart';

/// Reuses the existing public metadata read; no credentials or C1 signing state.
class DeviceEnvironmentChannel {
  const DeviceEnvironmentChannel({
    this.channel = const MethodChannel('com.vvtech.phone_agent/app_info'),
  });
  final MethodChannel channel;

  Future<DeviceEnvironment> read() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Mobile device metadata only');
    }
    final data = await channel.invokeMapMethod<String, Object?>(
      'readEnvironment',
    );
    if (data == null) throw const FormatException('Missing device metadata');
    String text(String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid device metadata: $key');
      }
      return value;
    }

    final os = text('osName');
    final expected = defaultTargetPlatform == TargetPlatform.iOS
        ? 'iOS'
        : 'Android';
    final build = data['appVersionCode'], api = data['apiLevel'];
    final hardware = data['deviceHardwareModel'];
    if (os != expected ||
        build is! int ||
        build < 0 ||
        (os == 'Android' && (api is! int || api <= 0)) ||
        (hardware != null && hardware is! String)) {
      throw const FormatException('Invalid device metadata');
    }
    return DeviceEnvironment(
      appVersion: text('appVersionName'),
      appBuild: build,
      osName: os,
      osVersion: text('osVersion'),
      brand: text('deviceBrand'),
      manufacturer: text('deviceManufacturer'),
      model: text('deviceModel'),
      hardwareModel: hardware as String? ?? '',
      apiLevel: os == 'Android' ? api as int : null,
    );
  }
}
