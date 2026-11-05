import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/config/app_config.dart';
import '../../auth/data/device_legacy_session_source.dart';
import '../domain/task_rating.dart';
import '../domain/task_rating_draft_store.dart';
import 'legacy_rating_draft_codec.dart';

class DeviceLegacyRatingDraft {
  const DeviceLegacyRatingDraft({
    required this.config,
    required this.accountId,
    this.platform,
    this.web,
    this.channel = const MethodChannel('phone_agent/legacy_rating_draft'),
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

  Future<SavedRatingDraft?> read(TaskRatingEligibility e) async {
    if (!eligible(config, platform: platform, web: web)) return null;
    try {
      bool valid(String value) =>
          value.trim().isNotEmpty &&
          value.length <= 256 &&
          !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);
      if (!valid(accountId) ||
          accountId == 'guest' ||
          !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(accountId) ||
          !valid(e.taskType) ||
          !valid(e.taskId)) {
        throw const FormatException();
      }
      final data = await channel.invokeMapMethod<String, Object?>('read', {
        'accountId': accountId,
        'taskType': e.taskType,
        'taskId': e.taskId,
      });
      if (data == null) return null;
      if (data['version'] != 1 ||
          data['accountId'] != accountId ||
          data['taskType'] != e.taskType ||
          data['taskId'] != e.taskId ||
          !data.containsKey('draft') ||
          (data['draft'] != null && data['draft'] is! String)) {
        throw const FormatException();
      }
      return LegacyRatingDraftCodec.decode(data['draft'] as String?);
    } catch (_) {
      throw const FormatException('Legacy rating draft unavailable');
    }
  }
}
