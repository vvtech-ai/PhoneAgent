import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/device_legacy_session_source.dart';
import '../features/translation/data/device_legacy_translation_archive.dart';
import 'app_providers.dart';

final legacyTranslationArchiveSourceProvider =
    Provider<DeviceLegacyTranslationArchive?>((ref) {
      if (kIsWeb ||
          defaultTargetPlatform != TargetPlatform.android ||
          !DeviceLegacySessionSource.eligible(ref.watch(appConfigProvider))) {
        return null;
      }
      return const DeviceLegacyTranslationArchive();
    });
