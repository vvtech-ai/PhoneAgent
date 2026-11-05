import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/data/voice/secure_voice_language_store.dart';
import 'app_providers.dart';
import 'legacy_preferences_providers.dart';

final voiceLanguageStoreProvider = Provider<SecureVoiceLanguageStore>((ref) {
  final config = ref.watch(appConfigProvider);
  final legacy = ref.watch(legacyPreferencesSourceProvider);
  return SecureVoiceLanguageStore(
    '${config.environment?.name}|${config.apiBaseUri}',
    legacyRead: legacy?.readVoiceLanguage,
  );
}, dependencies: [appConfigProvider, legacyPreferencesSourceProvider]);
