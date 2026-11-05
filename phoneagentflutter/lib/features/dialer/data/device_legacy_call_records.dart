import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/config/app_config.dart';
import '../../auth/data/device_legacy_session_source.dart';
import '../domain/app_call_record_repository.dart';
import '../domain/dial_recent_call.dart';
import 'legacy_app_call_record_codec.dart';

class DeviceLegacyCallRecords {
  const DeviceLegacyCallRecords({
    required this.config,
    required this.accountId,
    this.platform,
    this.web,
    this.channel = const MethodChannel('phone_agent/legacy_call_records'),
  });
  final AppConfig config;
  final String accountId;
  final TargetPlatform? platform;
  final bool? web;
  final MethodChannel channel;

  static bool eligible(
    AppConfig config, {
    TargetPlatform? platform,
    bool? web,
  }) =>
      !(web ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.android &&
      DeviceLegacySessionSource.eligible(config);

  Future<List<DialRecentCall>> read() async {
    if (!eligible(config, platform: platform, web: web)) return const [];
    if (accountId.isEmpty ||
        accountId.length > 256 ||
        accountId == 'guest' ||
        !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(accountId)) {
      throw const AppCallRecordFailure('legacy-invalid-owner');
    }
    try {
      final data = await channel.invokeMapMethod<String, Object?>('read', {
        'accountId': accountId,
      });
      if (data == null) return const [];
      if (data['version'] != 1 ||
          data['accountId'] != accountId ||
          !data.containsKey('records') ||
          (data['records'] != null && data['records'] is! String)) {
        throw const AppCallRecordFailure('legacy-invalid-envelope');
      }
      return LegacyAppCallRecordCodec.decode(data['records'] as String?);
    } on AppCallRecordFailure {
      rethrow;
    } catch (_) {
      throw const AppCallRecordFailure('legacy-unavailable');
    }
  }
}
