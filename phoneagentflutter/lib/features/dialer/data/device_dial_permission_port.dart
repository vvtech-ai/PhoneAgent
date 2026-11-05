import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../translation/data/translation_location_channel.dart';
import '../domain/dial_permission.dart';

class DeviceDialPermissionPort implements DialPermissionPort {
  const DeviceDialPermissionPort({
    this.channel = const MethodChannel('phone_agent/permissions'),
    this.platform,
    this.web,
  });
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;
  bool get _supported =>
      !(web ?? kIsWeb) &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(platform ?? defaultTargetPlatform);
  @override
  bool get supportsCallLog =>
      _supported &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.android;
  DialPermissionGrant _decode(String? value) => switch (value) {
    'granted' => DialPermissionGrant.granted,
    'denied' => DialPermissionGrant.denied,
    'blocked' => DialPermissionGrant.blocked,
    'unavailable' => DialPermissionGrant.unavailable,
    _ => throw const FormatException('Invalid dial permission response'),
  };
  @override
  Future<DialPermissionGrant> location({bool request = false}) async {
    if (!_supported) return DialPermissionGrant.unavailable;
    try {
      if (request) {
        return _decode(
          await channel.invokeMethod<String>('resolve', {
            'permission': 'location',
            'request': true,
          }),
        );
      }
      return _decode(await channel.invokeMethod<String>('locationStatus'));
    } on MissingPluginException {
      return DialPermissionGrant.unavailable;
    }
  }

  @override
  Future<DialPermissionGrant> callLog({bool request = false}) async {
    if (!supportsCallLog) return DialPermissionGrant.unavailable;
    return _decode(
      await channel.invokeMethod<String>('resolve', {
        'permission': 'callLog',
        'request': request,
      }),
    );
  }

  @override
  Future<void> openSettings() =>
      TranslationLocationChannel(platform: platform, web: web).openSettings();
}
