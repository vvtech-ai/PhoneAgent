import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/app_local_storage.dart';
import '../../../core/storage/preference_operation_queue.dart';
import '../domain/translation_preference_store.dart';
import '../domain/translation_preferences.dart';

class SecureTranslationPreferenceStore implements TranslationPreferenceStore {
  const SecureTranslationPreferenceStore(
    this.scope, {
    this.legacyRead,
    FlutterSecureStorage storage = const AppLocalStorage(
      preference: true,
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  }) : _storage = storage;
  final String scope;
  final FlutterSecureStorage _storage;
  final Future<TranslationPreferences?> Function()? legacyRead;
  String get key =>
      'phoneagent.translation.v1.${base64Url.encode(utf8.encode(scope))}';

  @override
  Future<TranslationPreferences> read() =>
      PreferenceOperationQueue.run(key, () async {
        final raw = await _storage.read(key: key);
        if (raw != null) return TranslationPreferenceCodec.decode(raw);
        final legacy = await legacyRead?.call();
        if (legacy == null) return const TranslationPreferences(caller: '');
        await _storage.write(
          key: key,
          value: TranslationPreferenceCodec.encode(legacy),
        );
        return legacy;
      });

  @override
  Future<void> write(TranslationPreferences value) =>
      PreferenceOperationQueue.run(
        key,
        () => _storage.write(
          key: key,
          value: TranslationPreferenceCodec.encode(value),
        ),
      );
}

abstract final class TranslationPreferenceCodec {
  static String encode(TranslationPreferences value) => jsonEncode({
    'schema': 1,
    'enabled': value.enabled,
    'prompt': value.prompt,
    'caller': value.caller,
    'peer': value.peer,
    'normalCountry': value.normalCountry,
    'translationCountry': value.translationCountry,
    'provider': value.provider,
    'domesticModelId': value.domesticModelId,
    'overseasModelId': value.overseasModelId,
    'region': value.region,
    'forceBackend': value.forceBackend,
    'simulatedCountryIso': value.simulatedCountryIso,
  });

  static TranslationPreferences decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> || value['schema'] != 1) {
      throw const FormatException('Unsupported translation preference schema');
    }
    String choice(String key, Iterable<String> allowed, String fallback) =>
        allowed.contains(value[key]) ? value[key] as String : fallback;
    String language(String key, String fallback) =>
        value[key] is String &&
            RegExp(
              r'^[a-zA-Z]{2,3}(?:-[a-zA-Z0-9]{2,8})*$',
            ).hasMatch(value[key] as String)
        ? value[key] as String
        : fallback;
    String country(String key) =>
        value[key] is String &&
            RegExp(r'^[A-Z]{2}$').hasMatch(value[key] as String)
        ? value[key] as String
        : 'CN';
    String modelId(String key) =>
        value[key] is String &&
            RegExp(r'^[A-Za-z0-9_.:-]{1,100}$').hasMatch(value[key] as String)
        ? value[key] as String
        : '';
    return TranslationPreferences(
      enabled: value['enabled'] is bool ? value['enabled'] as bool : true,
      prompt: value['prompt'] is bool ? value['prompt'] as bool : true,
      caller: value['caller'] == '' ? '' : language('caller', 'zh'),
      peer: language('peer', 'en'),
      normalCountry: country('normalCountry'),
      translationCountry: country('translationCountry'),
      provider: choice('provider', const [
        'OPENAI',
        'GEMINI',
        'QWEN',
      ], 'GEMINI'),
      domesticModelId: modelId('domesticModelId'),
      overseasModelId: modelId('overseasModelId'),
      region: choice('region', const ['DEFAULT', 'US', 'JP'], 'DEFAULT'),
      forceBackend: value['forceBackend'] == true,
      simulatedCountryIso:
          value['simulatedCountryIso'] is String &&
              RegExp(
                r'^[A-Z]{2}$',
              ).hasMatch(value['simulatedCountryIso'] as String)
          ? value['simulatedCountryIso'] as String
          : '',
    );
  }
}
