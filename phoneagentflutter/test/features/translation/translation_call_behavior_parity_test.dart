import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/data/secure_translation_preference_store.dart';
import 'package:phone_agent/features/translation/domain/translation_model_selection.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/domain/translation_dial_request.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_connected_duration.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_call_plan.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/dialer/domain/dial_phone_policy.dart';
import 'package:phone_agent/features/dialer/domain/dial_country.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_phone_format_confirmation.dart';
import '../../support/translation_directory_fixture.dart';

void main() {
  test('country bound model transport overrides geographic assumptions', () {
    final dto = translationOptionsFixture();
    (dto['models'] as List).add(<String, Object>{
      ...Map<String, Object>.from((dto['models'] as List).first as Map),
      'modelId': 'qwen-international',
      'providerCode': 'dashscope-intl',
      'transport': 'BACKEND_WEBRTC',
    });
    for (final c in dto['countries'] as List) {
      if ((c as Map)['countryCode'] == 'CN') {
        c['availableModelIds'] = ['OPENAI'];
      }
      if (c['countryCode'] == 'US') {
        c['availableModelIds'] = ['QWEN_OMNI_PLUS', 'qwen-international'];
      }
    }
    final directory = ApiTranslationDirectory.decode(dto);
    expect(
      selectTranslationModel(
        directory,
        const TranslationPreferences(),
        'CN',
      )!.transport,
      'BACKEND_WEBRTC',
    );
    expect(
      selectTranslationModel(
        directory,
        const TranslationPreferences(),
        'US',
      )!.transport,
      'LOCAL_SIP',
    );
    const prefs = TranslationPreferences(
      provider: 'QWEN',
      overseasModelId: 'qwen-international',
    );
    expect(
      selectTranslationModel(directory, prefs, 'US')!.id,
      'qwen-international',
    );
    expect(selectTranslationModel(directory, prefs, 'CN')!.id, 'OPENAI');
    expect(
      TranslationPreferenceCodec.decode(
        TranslationPreferenceCodec.encode(prefs),
      ).provider,
      'QWEN',
    );
    final dial = TranslationDialRequest(
      rawNumber: '2025550123',
      countryIso: 'US',
      callerCountryIso: 'US',
      displayName: '',
      preferences: prefs,
      modelId: 'qwen-international',
    );
    expect(
      dial
          .toCreateRequest(
            userId: 'synthetic',
            originalAudio: const OriginalAudioSettings(),
          )
          .toJson()['realtimeProvider'],
      'qwen3.5-livetranslate-flash-realtime',
    );
    expect(dial.serviceRegion, 'US');
  });

  test('non-China local SIP compares caller and callee countries', () {
    TranslationCallPlan plan(String callee, String raw) =>
        TranslationCallPlan.resolve(
          location: TrustedTranslationLocation('US', 1),
          rawNumber: raw,
          targetCountry: callee,
          preferences: const TranslationPreferences(),
          modelTransport: 'LOCAL_SIP',
          domestic: internalDefaultSipPreferences,
        );
    expect(plan('US', '2025550123').leaseRoute, 'domestic');
    expect(plan('US', '2025550123').networkNumber, '0012025550123');
    expect(plan('CN', '13800138000').leaseRoute, 'international');
    final backend = TranslationCallPlan.resolve(
      location: TrustedTranslationLocation('CN', 1),
      rawNumber: '+12025550123',
      targetCountry: 'US',
      modelTransport: 'BACKEND_WEBRTC',
      preferences: const TranslationPreferences(provider: 'QWEN'),
    );
    expect(backend.transport, TranslationCallTransport.overseas);
    expect(
      () => TranslationCallPlan.resolve(
        location: null,
        rawNumber: '2025550123',
        targetCountry: 'US',
        modelTransport: 'LOCAL_SIP',
        preferences: const TranslationPreferences(),
      ),
      throwsA(isA<TranslationPlanFailure>()),
    );
  });

  test('display duration rounds up, clamps negative and integer maximum', () {
    for (final entry in {
      -1: 0,
      0: 0,
      1: 1,
      999: 1,
      1000: 1,
      1001: 2,
      2147483648000: 2147483647,
    }.entries) {
      expect(translationConnectedSeconds(entry.key), entry.value);
    }
  });

  test('format warning enables only native bounded numeric fallback', () {
    final dto = translationOptionsFixture();
    ((dto['countries'] as List).first as Map)['phoneRegex'] =
        r'^1[3-9][0-9]{9}$';
    final country = ApiTranslationDirectory.decode(dto).country('CN');
    expect(
      translationPhoneNeedsWarning('123456789', dialCountry('CN')!, country),
      true,
    );
    expect(
      translationPhoneNeedsWarning('13800138000', dialCountry('CN')!, country),
      false,
    );
    expect(
      translationPhoneNeedsWarning('+86123456789', dialCountry('CN')!, country),
      false,
    );
    expect(DialPhonePolicy.resolveForCall('123456789', 'CN'), isNull);
    final confirmed = DialPhonePolicy.resolveForCall(
      '123456789',
      'CN',
      allowUnverifiedNumber: true,
    )!;
    expect(confirmed.number, '+86123456789');
    expect(confirmed.networkNumber, '123456789');
    for (final raw in ['12', '123456789012345', 'abc', '12x1']) {
      expect(
        DialPhonePolicy.resolveForCall(raw, 'CN', allowUnverifiedNumber: true),
        isNull,
      );
    }
    expect(
      DialPhonePolicy.resolveForCall('123', 'XX', allowUnverifiedNumber: true),
      isNull,
    );
    final dial = TranslationDialRequest(
      rawNumber: '202',
      countryIso: 'US',
      displayName: '',
      preferences: const TranslationPreferences(),
      allowUnverifiedNumber: true,
    );
    expect(dial.phone, '+1202');
    expect(
      DialPhonePolicy.resolve('+86 10 12345678', 'CN')!.networkNumber,
      '01012345678',
    );
  });
}
