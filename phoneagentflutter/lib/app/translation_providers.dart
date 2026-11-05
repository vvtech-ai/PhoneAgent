import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/data/secure_translation_preference_store.dart';
import '../features/translation/domain/translation_preference_store.dart';
import '../features/translation/presentation/controller/translation_setup_controller.dart';
import 'app_providers.dart';
import 'translation_directory_providers.dart';
import 'legacy_preferences_providers.dart';

final translationPreferenceStoreProvider = Provider<TranslationPreferenceStore>(
  (ref) {
    final config = ref.watch(appConfigProvider);
    return SecureTranslationPreferenceStore(
      '${config.environment?.name}|${config.apiBaseUri}',
      legacyRead: ref.watch(legacyPreferencesSourceProvider)?.readTranslation,
    );
  },
);

// Device preferences survive page closes/account changes, but not environment changes.
final translationSetupProvider =
    StateNotifierProvider<TranslationSetupController, TranslationSetupState>((
      ref,
    ) {
      final controller = TranslationSetupController(
        store: ref.watch(translationPreferenceStoreProvider),
      );
      ref.listen(translationDirectoryProvider, (previous, next) {
        controller.directory(
          !next.isLoading && !next.hasError ? next.valueOrNull : null,
        );
      }, fireImmediately: true);
      controller.load();
      return controller;
    });
