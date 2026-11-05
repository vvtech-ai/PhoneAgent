import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/data/secure_original_audio_store.dart';
import '../features/settings/domain/original_audio_settings.dart';
import '../features/settings/presentation/controller/original_audio_controller.dart';
import 'app_providers.dart';
import 'legacy_preferences_providers.dart';

// v65 developer visibility is process-local, not a persisted security gate.
final developerModeProvider = StateProvider<bool>((ref) => false);
final originalAudioStoreProvider = Provider<OriginalAudioStore>((ref) {
  final config = ref.watch(appConfigProvider);
  return SecureOriginalAudioStore(
    '${config.environment?.name}|${config.apiBaseUri}',
    legacyRead: ref.watch(legacyPreferencesSourceProvider)?.readOriginalAudio,
  );
});
// Device preference intentionally survives account changes and route closes.
final originalAudioControllerProvider =
    StateNotifierProvider<OriginalAudioController, OriginalAudioState>((ref) {
      final controller = OriginalAudioController(
        ref.watch(originalAudioStoreProvider),
      );
      controller.load();
      return controller;
    });
