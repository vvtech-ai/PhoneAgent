import 'translation_preferences.dart';

abstract interface class TranslationPreferenceStore {
  Future<TranslationPreferences> read();
  Future<void> write(TranslationPreferences value);
}
