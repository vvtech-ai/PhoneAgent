import '../../dialer/domain/dial_country.dart';
import '../../dialer/domain/dial_phone_policy.dart';
import '../../settings/domain/original_audio_settings.dart';
import 'translation_backend_session.dart';
import 'translation_preferences.dart';

/// Immutable confirmation snapshot; the region is a service node, not location.
class TranslationDialRequest {
  TranslationDialRequest({
    required String rawNumber,
    required this.countryIso,
    required this.displayName,
    required this.preferences,
    this.callerCountryIso = '',
    this.modelId = '',
    this.allowUnverifiedNumber = false,
    DialCountry? configuredCountry,
  }) : phone = _phone(
         rawNumber,
         countryIso,
         preferences,
         configuredCountry,
         allowUnverifiedNumber,
       );
  final String phone, countryIso, displayName, modelId, callerCountryIso;
  final TranslationPreferences preferences;
  final bool allowUnverifiedNumber;
  String get serviceRegion {
    final country =
        (callerCountryIso.isEmpty
                ? preferences.simulatedCountryIso
                : callerCountryIso)
            .trim()
            .toUpperCase();
    // Standalone previews/legacy callers without a location keep their fixture.
    if (country.isEmpty) return preferences.region;
    if (country == 'CN' && preferences.forceBackend) return 'US';
    return const {'US': 'US', 'JP': 'JP'}[country] ?? 'DEFAULT';
  }

  String get targetLabel => displayName.trim().isEmpty ? phone : displayName;

  static String _phone(
    String raw,
    String iso,
    TranslationPreferences value,
    DialCountry? configuredCountry,
    bool allowUnverifiedNumber,
  ) {
    final target = DialPhonePolicy.resolveForCall(
      raw,
      iso,
      configuredCountry: configuredCountry,
      allowUnverifiedNumber: allowUnverifiedNumber,
    );
    if (!value.enabled ||
        target == null ||
        !RegExp(r'^\+[1-9][0-9]{3,14}$').hasMatch(target.number) ||
        !const {'OPENAI', 'GEMINI', 'QWEN'}.contains(value.provider) ||
        !const {'DEFAULT', 'US', 'JP'}.contains(value.region)) {
      throw const FormatException('Invalid overseas dial request');
    }
    // Extension belongs to manual DTMF after connection, never create payload.
    return target.number;
  }

  TranslationCreateRequest toCreateRequest({
    required String userId,
    required OriginalAudioSettings originalAudio,
  }) => TranslationCreateRequest(
    phone: phone,
    userLanguage: preferences.caller,
    merchantLanguage: preferences.peer,
    provider: preferences.provider,
    userId: userId,
    originalAudioEnabled: originalAudio.enabled,
    originalAudioPercent: originalAudio.gain,
    originalAudioVolumePercent: originalAudio.volume,
  );
}
