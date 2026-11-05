import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/app_update/data/device_legacy_preferences.dart';
import '../features/auth/data/device_legacy_session_source.dart';
import 'app_providers.dart';

// Native channel separately verifies the actual installed production package.
final legacyPreferencesSourceProvider = Provider<DeviceLegacyPreferences?>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      !DeviceLegacySessionSource.eligible(config)) {
    return null;
  }
  return const DeviceLegacyPreferences();
});
