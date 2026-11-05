import 'package:flutter/services.dart';
import '../../dialer/domain/dial_country.dart';
import '../../settings/domain/original_audio_settings.dart';
import '../../translation/domain/translation_preferences.dart';
import '../../translation/domain/translation_location.dart';

/// Only the fixed v65 whitelist crosses this channel; no source files are edited.
class DeviceLegacyPreferences {
  const DeviceLegacyPreferences();
  static const channel = MethodChannel(
    'com.vvtech.phone_agent/legacy_preferences',
  );

  Future<Map<Object?, Object?>?> _section(String key) async {
    final data = await channel.invokeMapMethod<String, Object?>('read');
    if (data == null) return null;
    if (data['version'] != 1) {
      throw const FormatException('Unknown legacy preferences');
    }
    final value = data[key];
    if (value == null) return null;
    if (value is! Map) {
      throw const FormatException('Invalid legacy preferences');
    }
    return value;
  }

  static T _value<T>(Map<Object?, Object?> data, String key, T fallback) {
    if (!data.containsKey(key)) return fallback;
    final value = data[key];
    if (value is! T) {
      throw const FormatException('Invalid legacy preference type');
    }
    return value;
  }

  Future<OriginalAudioSettings?> readOriginalAudio() async {
    final data = await _section('originalAudio');
    if (data == null) return null;
    return OriginalAudioSettings(
      enabled: _value(data, 'enabled', false),
      gain: OriginalAudioSettings.level(_value(data, 'gain', 50), 50),
      volume: OriginalAudioSettings.level(_value(data, 'volume', 100), 100),
    );
  }

  Future<bool?> readInitializationSkipped() async {
    final data = await _section('initialization');
    if (data == null) return null;
    final value = data['skipped'];
    if (value is! bool) {
      throw const FormatException('Invalid legacy initialization preference');
    }
    return value;
  }

  Future<String?> readVoiceLanguage() async {
    final data = await _section('voice');
    if (data == null) return null;
    final value = data['language'];
    if (value is! String) {
      throw const FormatException('Invalid legacy voice language');
    }
    return value;
  }

  Future<TrustedTranslationLocation?> readLocation() async {
    final data = await _section('location');
    if (data == null) return null;
    final iso = data['countryIso'];
    final sampledAt = data['sampledAtMs'];
    if (iso is! String || sampledAt is! int) {
      throw const FormatException('Invalid legacy location cache');
    }
    return TrustedTranslationLocation(iso, sampledAt);
  }

  Future<TranslationPreferences?> readTranslation() async {
    final data = await _section('translation');
    if (data == null) return null;
    String text(String key, [String fallback = '']) =>
        _value(data, key, fallback);
    String language(String key, String fallback) {
      final raw = text(key);
      for (final item in translationLanguages) {
        if (raw == item.label || raw == item.code) return item.code;
      }
      return fallback;
    }

    String country(String key) {
      final raw = text(key, 'CN').toUpperCase();
      return dialCountry(raw) == null ? 'CN' : raw;
    }

    final provider = text('provider').trim().toUpperCase();
    final region = text('region').trim().toUpperCase();
    return TranslationPreferences(
      enabled: _value(data, 'enabled', true),
      prompt: _value(data, 'prompt', true),
      caller: language('caller', 'zh'),
      peer: language('peer', 'en'),
      normalCountry: country('normalCountry'),
      translationCountry: country('translationCountry'),
      provider: const {'OPENAI', 'OPEN_AI'}.contains(provider)
          ? 'OPENAI'
          : 'GEMINI',
      region: const {'US', 'UNITEDSTATES', 'UNITED_STATES'}.contains(region)
          ? 'US'
          : const {'JP', 'JAPAN'}.contains(region)
          ? 'JP'
          : 'DEFAULT',
      forceBackend: _value(data, 'forceBackend', false),
    );
  }
}
