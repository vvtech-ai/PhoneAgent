import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/tools/conversation_permission.dart';
import '../../../translation/data/translation_location_channel.dart';
import 'permission_settings_return.dart';

/// No data acquisition: only system authorization checks and user prompts.
class DevicePermissionChannel
    implements
        ConversationPermissionSource,
        ConversationPermissionSettingsSource {
  const DevicePermissionChannel({
    this.channel = const MethodChannel('phone_agent/permissions'),
    this.platform,
    this.web,
  });
  final MethodChannel channel;
  final TargetPlatform? platform;
  final bool? web;

  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    if (permission == ConversationPermission.documentPicker) {
      return PermissionGrant.granted;
    }
    final current = platform ?? defaultTargetPlatform;
    if ((web ?? kIsWeb) ||
        !{TargetPlatform.android, TargetPlatform.iOS}.contains(current)) {
      return PermissionGrant.unavailable;
    }
    final status = await channel
        .invokeMethod<String>('resolve', {
          'permission': permission.name,
          'request': request,
        })
        .timeout(const Duration(seconds: 90));
    return switch (status) {
      'granted' => PermissionGrant.granted,
      'denied' => PermissionGrant.denied,
      'blocked' => PermissionGrant.blocked,
      'unavailable' => PermissionGrant.unavailable,
      _ => throw const FormatException('Invalid system permission response'),
    };
  }

  @override
  Future<void> openSettings() => waitForPermissionSettingsReturn(
    TranslationLocationChannel(platform: platform, web: web).openSettings,
  );
}
