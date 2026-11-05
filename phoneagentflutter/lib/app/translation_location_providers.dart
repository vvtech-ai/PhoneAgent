import 'package:flutter/foundation.dart';
import 'dial_permission_providers.dart';
import '../features/dialer/domain/dial_permission.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/data/secure_translation_location_store.dart';
import '../features/translation/data/translation_location_channel.dart';
import '../features/translation/domain/translation_location.dart';
import '../features/translation/presentation/controller/translation_location_controller.dart';
import 'app_providers.dart';
import 'translation_providers.dart';
import 'legacy_preferences_providers.dart';

final translationLocationSourceProvider =
    Provider.autoDispose<TranslationLocationSource>(
      (ref) => TranslationLocationChannel(),
    );
final translationLocationStoreProvider =
    Provider.autoDispose<TranslationLocationStore>((ref) {
      final config = ref.watch(appConfigProvider);
      return SecureTranslationLocationStore(
        '${config.environment?.name}|${config.apiBaseUri}',
        legacyRead: ref.watch(legacyPreferencesSourceProvider)?.readLocation,
      );
    });
final translationLocationProvider =
    StateNotifierProvider.autoDispose<
      TranslationLocationController,
      TranslationLocationState
    >((ref) {
      final permission =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? ref.watch(dialPermissionPortProvider)
          : null;
      final controller = TranslationLocationController(
        ref.watch(translationLocationSourceProvider),
        ref.watch(translationLocationStoreProvider),
        readAndroidPermission: permission == null
            ? null
            : () async => switch (await permission.location()) {
                DialPermissionGrant.granted =>
                  TranslationLocationStatus.resolved,
                DialPermissionGrant.denied => TranslationLocationStatus.denied,
                DialPermissionGrant.blocked =>
                  TranslationLocationStatus.blocked,
                DialPermissionGrant.unavailable =>
                  TranslationLocationStatus.unavailable,
              },
      );
      controller.load();
      return controller;
    });

/// Debug country overlays the translation region without touching GPS/cache.
final effectiveTranslationLocationProvider =
    Provider.autoDispose<TranslationLocationState>((ref) {
      final iso = ref.watch(
        translationSetupProvider.select(
          (state) => state.ready ? state.value.simulatedCountryIso : '',
        ),
      );
      final real = ref.watch(translationLocationProvider);
      if (iso.isEmpty) return real;
      return TranslationLocationState(
        status: TranslationLocationStatus.resolved,
        trusted: TrustedTranslationLocation(iso, 1),
      );
    });
