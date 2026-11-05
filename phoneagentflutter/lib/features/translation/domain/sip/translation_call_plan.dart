import '../../../dialer/domain/dial_country.dart';
import '../../../dialer/domain/dial_phone_policy.dart';
import '../translation_location.dart';
import '../translation_preferences.dart';

enum TranslationCallTransport { overseas, domesticSip, internationalSip }

class DomesticTranslationPreferences {
  const DomesticTranslationPreferences({
    this.provider = 'QWEN',
    this.domesticAccountId = '',
    this.internationalAccountId = '',
  });
  final String provider, domesticAccountId, internationalAccountId;
  DomesticTranslationPreferences copy({
    String? provider,
    String? domesticAccountId,
    String? internationalAccountId,
  }) => DomesticTranslationPreferences(
    provider: provider ?? this.provider,
    domesticAccountId: domesticAccountId ?? this.domesticAccountId,
    internationalAccountId:
        internationalAccountId ?? this.internationalAccountId,
  );
}

/// Compatibility defaults for route planning only. Actual SIP credentials and
/// account are supplied by the server lease, never by a user preference.
const internalDefaultSipPreferences = DomesticTranslationPreferences(
  domesticAccountId: '21311802',
  internationalAccountId: '21311802',
);

/// Frozen shared route. No network, account credentials or automatic DTMF.
class TranslationCallPlan {
  const TranslationCallPlan._({
    required this.locationCountry,
    required this.target,
    required this.networkNumber,
    required this.extension,
    required this.transport,
    required this.provider,
    required this.serviceRegion,
    required this.callerLanguage,
    required this.peerLanguage,
    this.sipAccountId = '',
    this.modelId = '',
  });
  final String locationCountry, target, networkNumber, extension;
  final String provider, serviceRegion, callerLanguage, peerLanguage;
  final String sipAccountId, modelId;
  final TranslationCallTransport transport;
  bool get usesSip => transport != TranslationCallTransport.overseas;
  String get leaseRoute => transport == TranslationCallTransport.domesticSip
      ? 'domestic'
      : 'international';

  static TranslationCallPlan resolve({
    required TrustedTranslationLocation? location,
    required String rawNumber,
    required String targetCountry,
    required TranslationPreferences preferences,
    DomesticTranslationPreferences domestic =
        const DomesticTranslationPreferences(),
    bool testControlsEnabled = false,
    bool serverLanguages = false,
    String modelId = '',
    String? modelTransport,
    bool allowUnverifiedNumber = false,
    DialCountry? configuredCountry,
  }) {
    if (location == null) {
      throw const TranslationPlanFailure('LOCATION_UNAVAILABLE', '主叫所在国家尚未确认');
    }
    if (!preferences.enabled) {
      throw const TranslationPlanFailure('DISABLED', '实时翻译未开启');
    }
    final compact = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (compact.contains('+') &&
        (!compact.startsWith('+') || '+'.allMatches(compact).length != 1)) {
      throw const TranslationPlanFailure('INVALID_NUMBER', '请输入有效电话号码');
    }
    final target = DialPhonePolicy.resolveForCall(
      rawNumber,
      targetCountry,
      allowUnverifiedNumber: allowUnverifiedNumber,
      configuredCountry: configuredCountry,
    );
    if (target == null) {
      throw const TranslationPlanFailure('INVALID_NUMBER', '请输入有效电话号码');
    }
    final languages = translationLanguages.map((value) => value.code).toSet();
    if (!serverLanguages &&
        (!languages.contains(preferences.caller) ||
            !languages.contains(preferences.peer))) {
      throw const TranslationPlanFailure('INVALID_LANGUAGE', '请选择有效的翻译语言');
    }
    if (modelTransport != null &&
        !const {'LOCAL_SIP', 'BACKEND_WEBRTC'}.contains(modelTransport)) {
      throw const TranslationPlanFailure('INVALID_ROUTE', '翻译模型承载路线未配置');
    }
    final overseas = modelTransport == null
        ? location.countryIso != 'CN' ||
              (testControlsEnabled && preferences.forceBackend)
        : modelTransport == 'BACKEND_WEBRTC';
    if (overseas) {
      if (!const {'OPENAI', 'GEMINI', 'QWEN'}.contains(preferences.provider)) {
        throw const TranslationPlanFailure(
          'INVALID_OVERSEAS_PROVIDER',
          'WebRTC 实时翻译仅支持 OpenAI、Gemini 或千问国际站',
        );
      }
      if (!RegExp(r'^\+[1-9][0-9]{3,14}$').hasMatch(target.number) ||
          !const {'DEFAULT', 'US', 'JP'}.contains(preferences.region)) {
        throw const TranslationPlanFailure(
          'INVALID_OVERSEAS_ROUTE',
          '号码或海外服务区域不可用',
        );
      }
    } else {
      if (!const {'QWEN', 'DOUBAO'}.contains(domestic.provider)) {
        throw const TranslationPlanFailure(
          'INVALID_DOMESTIC_PROVIDER',
          'App SIP 实时翻译仅支持千问或豆包',
        );
      }
      if (domestic.provider == 'DOUBAO' &&
          (preferences.caller == preferences.peer ||
              preferences.caller == 'ko' ||
              preferences.peer == 'ko' ||
              !{
                preferences.caller,
                preferences.peer,
              }.any(const {'zh', 'en'}.contains))) {
        throw const TranslationPlanFailure(
          'INVALID_LANGUAGE_PAIR',
          '豆包实时翻译暂不支持该语种组合，请选择不同语言后再拨打',
        );
      }
    }
    final sameCountry =
        location.countryIso.toUpperCase() == targetCountry.toUpperCase();
    final accountId = overseas
        ? ''
        : (sameCountry
                  ? domestic.domesticAccountId
                  : domestic.internationalAccountId)
              .trim();
    if (!overseas && accountId.isEmpty) {
      throw TranslationPlanFailure(
        'MISSING_SIP_ACCOUNT',
        sameCountry ? '请先选择国内 SIP 账号' : '请先选择国际 SIP 账号',
      );
    }
    return TranslationCallPlan._(
      locationCountry: location.countryIso,
      modelId: modelId,
      target: target.number,
      networkNumber: overseas
          ? target.number
          : target.networkNumber ?? _networkNumber(target.number),
      extension: target.extension,
      transport: overseas
          ? TranslationCallTransport.overseas
          : sameCountry
          ? TranslationCallTransport.domesticSip
          : TranslationCallTransport.internationalSip,
      provider: overseas ? preferences.provider : domestic.provider,
      serviceRegion: preferences.region,
      sipAccountId: accountId,
      callerLanguage: preferences.caller,
      peerLanguage: preferences.peer,
    );
  }

  static String _networkNumber(String target) {
    if (!target.startsWith('+')) return target;
    if (!target.startsWith('+86')) return '00${target.substring(1)}';
    final national = target.substring(3);
    if (RegExp(r'^1[3-9][0-9]{9}$').hasMatch(national) ||
        RegExp(r'^(400|800|95|96)').hasMatch(national) ||
        national.startsWith('0') ||
        national.length < 9) {
      return national;
    }
    return '0$national';
  }
}

class TranslationPlanFailure implements Exception {
  const TranslationPlanFailure(this.code, this.message);
  final String code, message;
  @override
  String toString() => 'TranslationPlanFailure($code)';
}
