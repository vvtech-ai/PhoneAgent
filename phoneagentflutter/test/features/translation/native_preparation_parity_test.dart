import 'package:phone_agent/features/translation/domain/translation_dial_request.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_service_catalog.dart';
import 'package:phone_agent/features/translation/domain/translation_session_coordinator.dart';
import 'package:phone_agent/features/translation/domain/translation_preparation_policy.dart';
import '../../support/translation_session_fixture.dart';

void main() {
  for (final (country, region) in [
    ('US', 'US'),
    ('JP', 'JP'),
    ('SG', 'DEFAULT'),
    ('CN', 'US'),
  ]) {
    test(
      'caller $country freezes native region $region over old preference',
      () {
        final request = TranslationDialRequest(
          rawNumber: '+12025550101',
          countryIso: 'US',
          displayName: '',
          callerCountryIso: country,
          preferences: const TranslationPreferences(
            provider: 'OPENAI',
            region: 'JP',
            forceBackend: true,
          ),
        );
        expect(request.serviceRegion, region);
      },
    );
  }
  for (final input in ['en', ' EN ', 'English', '英语']) {
    test('native lookup accepts $input using code or label', () {
      const catalog = TranslationServiceCatalog([
        TranslationServiceLanguage('en', '英语'),
        TranslationServiceLanguage('en-US', 'English'),
      ]);
      expect(
        resolveTranslationLanguage(input, catalog),
        input.trim().toLowerCase() == 'en' || input == '英语' ? 'en' : 'en-US',
      );
    });
  }
  test('native aliases and label match preserve actual server code', () {
    const catalog = TranslationServiceCatalog([
      TranslationServiceLanguage('zh-CN', '中文'),
      TranslationServiceLanguage('ja-JP', '日语'),
      TranslationServiceLanguage('custom', 'custom-language'),
    ]);
    expect(resolveTranslationLanguage('mandarin chinese', catalog), 'zh-CN');
    expect(resolveTranslationLanguage('日文', catalog), 'ja-JP');
    expect(resolveTranslationLanguage('CUSTOM-LANGUAGE', catalog), 'custom');
  });
  test('short code catalog proceeds to create then exactly one dial', () async {
    final f = SessionFixture()
      ..catalog = const TranslationServiceCatalog([
        TranslationServiceLanguage('zh', '中文'),
        TranslationServiceLanguage('en', '英语'),
      ]);
    await f.coordinator.start(translationRequest);
    expect(f.backend.received!.userLanguage, 'zh');
    expect(f.backend.received!.merchantLanguage, 'en');
    expect(f.events.where((e) => e == 'merchant'), hasLength(1));
    await f.coordinator.stop();
  });
  test(
    'unsupported language explains rejection without creating session',
    () async {
      final f = SessionFixture()..catalog = const TranslationServiceCatalog([]);
      await f.coordinator.start(translationRequest);
      expect(f.errors.last, '通话未接通，请稍后重试');
      expect(f.events, ['languages']);
    },
  );
  test(
    'create HTTP rejection has stage/status; no raw error exposure',
    () async {
      final f = SessionFixture();
      f.backend.createFailure = const TranslationBackendFailure(
        'private-token',
        status: 400,
      );
      await f.coordinator.start(translationRequest);
      expect(f.errors.last, '通话未接通，请稍后重试');
      expect(f.errors.last, isNot(contains('private-token')));
      expect(f.events, ['languages', 'create']);
    },
  );
  test(
    'media failure uses native fallback and reclaims known session without dial',
    () async {
      final f = SessionFixture();
      f.live.fail = f.ws.fail = true;
      await f.coordinator.start(translationRequest);
      expect(f.errors.last, '通话未接通，请稍后重试');
      expect(f.events.last, 'hangup');
      expect(f.events, isNot(contains('merchant')));
    },
  );
  test('provider not started keeps failed state and native fallback', () async {
    final f = SessionFixture();
    f.backend.started = false;
    await f.coordinator.start(translationRequest);
    expect(f.errors.last, '通话未接通，请稍后重试');
    expect(f.events.where((e) => e == 'merchant'), hasLength(1));
    expect(f.coordinator.stage, TranslationSessionStage.failed);
  });
  test('failed cleanup preserves original reason and uncertainty', () async {
    final f = SessionFixture();
    f.backend.started = false;
    f.backend.hangupFails = true;
    await f.coordinator.start(translationRequest);
    expect(f.errors.last, contains('通话未接通，请稍后重试'));
    expect(f.coordinator.cleanupUnconfirmed, true);
    expect(f.coordinator.stage, TranslationSessionStage.failed);
  });
}
