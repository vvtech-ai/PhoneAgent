import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_call_plan.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';

void main() {
  TranslationCallPlan plan({
    String? location = 'CN',
    String number = '13800138000',
    String country = 'CN',
    TranslationPreferences preferences = const TranslationPreferences(),
    String provider = 'QWEN',
    String domestic = 'synthetic-local',
    String international = 'synthetic-world',
    bool testing = false,
  }) => TranslationCallPlan.resolve(
    location: location == null ? null : TrustedTranslationLocation(location, 1),
    rawNumber: number,
    targetCountry: country,
    preferences: preferences,
    domestic: DomesticTranslationPreferences(
      provider: provider,
      domesticAccountId: domestic,
      internationalAccountId: international,
    ),
    testControlsEnabled: testing,
  );
  Matcher failure(String code) =>
      isA<TranslationPlanFailure>().having((value) => value.code, 'code', code);

  test('trusted location, not target or service node, selects transport', () {
    final local = plan(preferences: const TranslationPreferences(region: 'US'));
    expect(local.transport, TranslationCallTransport.domesticSip);
    expect(local.networkNumber, '13800138000');
    expect(local.leaseRoute, 'domestic');
    expect(local.sipAccountId, 'synthetic-local');
    final foreign = plan(number: '+12025550101', country: 'US');
    expect(foreign.transport, TranslationCallTransport.internationalSip);
    expect(foreign.networkNumber, '0012025550101');
    expect(foreign.sipAccountId, 'synthetic-world');
    final overseas = plan(location: 'US');
    expect(overseas.transport, TranslationCallTransport.overseas);
    expect(overseas.provider, 'GEMINI');
    expect(overseas.sipAccountId, isEmpty);
  });
  test('landline short number and manual extension remain separated', () {
    final landline = plan(number: '+86 10 12345678 转123');
    expect(landline.target, '+861012345678');
    expect(landline.networkNumber, '01012345678');
    expect(landline.extension, '123');
    expect(plan(number: '10086').networkNumber, '10086');
    expect(
      () => plan(location: 'US', number: '10086'),
      throwsA(failure('INVALID_OVERSEAS_ROUTE')),
    );
  });
  test('unknown location and non-development force never bypass admission', () {
    expect(
      () => plan(
        location: null,
        testing: true,
        preferences: const TranslationPreferences(forceBackend: true),
      ),
      throwsA(failure('LOCATION_UNAVAILABLE')),
    );
    expect(
      plan(
        preferences: const TranslationPreferences(forceBackend: true),
      ).usesSip,
      isTrue,
    );
    expect(
      plan(
        testing: true,
        preferences: const TranslationPreferences(forceBackend: true),
      ).usesSip,
      isFalse,
    );
  });
  test('model and account checks are specific to selected route', () {
    expect(
      () => plan(provider: 'GEMINI'),
      throwsA(failure('INVALID_DOMESTIC_PROVIDER')),
    );
    expect(() => plan(domestic: ''), throwsA(failure('MISSING_SIP_ACCOUNT')));
    expect(
      () => plan(number: '+12025550101', country: 'US', international: ''),
      throwsA(failure('MISSING_SIP_ACCOUNT')),
    );
    expect(
      () => plan(
        location: 'US',
        preferences: const TranslationPreferences(provider: 'DOUBAO'),
      ),
      throwsA(failure('INVALID_OVERSEAS_PROVIDER')),
    );
    expect(() => plan(number: '12+3456'), throwsA(failure('INVALID_NUMBER')));
    expect(
      () => plan(preferences: const TranslationPreferences(enabled: false)),
      throwsA(failure('DISABLED')),
    );
  });
  test('Doubao rejects unsupported or identical language pairs', () {
    for (final preferences in [
      const TranslationPreferences(caller: 'ko'),
      const TranslationPreferences(caller: 'ja', peer: 'fr'),
      const TranslationPreferences(caller: 'en', peer: 'en'),
    ]) {
      expect(
        () => plan(provider: 'DOUBAO', preferences: preferences),
        throwsA(failure('INVALID_LANGUAGE_PAIR')),
      );
    }
    expect(
      plan(
        provider: 'DOUBAO',
        preferences: const TranslationPreferences(peer: 'ja'),
      ).provider,
      'DOUBAO',
    );
  });
}
