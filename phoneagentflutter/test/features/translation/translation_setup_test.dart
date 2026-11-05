import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import '../../support/translation_directory_fixture.dart';

void main() {
  test('v65 defaults and visible language catalog, no domestic model', () {
    final c = TranslationSetupController();
    addTearDown(c.dispose);
    expect(c.snapshot.enabled, isTrue);
    expect(c.snapshot.prompt, isTrue);
    expect(c.snapshot.provider, 'GEMINI');
    expect(c.snapshot.caller, 'zh');
    expect(c.snapshot.peer, 'en');
    expect(translationLanguages.map((e) => e.code), [
      'zh',
      'en',
      'ja',
      'ko',
      'fr',
      'de',
      'es',
    ]);
    c.provider('DOUBAO');
    c.region('CN');
    expect(c.snapshot.provider, 'GEMINI');
    expect(c.snapshot.region, 'DEFAULT');
  });
  test(
    'mode remembers own country and toggling does not overwrite language',
    () {
      final c = TranslationSetupController()
        ..directory(syntheticTranslationDirectory);
      addTearDown(c.dispose);
      c.country('JP');
      expect(c.snapshot.peer, 'en');
      c.language('fr', caller: false);
      c.enable(false);
      expect(c.snapshot.country, 'CN');
      expect(c.snapshot.peer, 'fr');
      c.country('SG');
      expect(c.snapshot.peer, 'en');
      c.enable(true);
      expect(c.snapshot.country, 'JP');
      expect(c.snapshot.peer, 'en');
      c.enable(false);
      expect(c.snapshot.country, 'SG');
    },
  );
  test('disabled language, invalid country and provider are ignored', () {
    final c = TranslationSetupController();
    addTearDown(c.dispose);
    c.country('xx');
    c.language('bad', caller: true);
    expect(c.snapshot.country, 'CN');
    expect(c.snapshot.caller, 'zh');
    c.enable(false);
    c.language('ja', caller: true);
    expect(c.snapshot.caller, 'zh');
    c.provider('OPENAI');
    c.region('JP');
    c.prompt(false);
    expect(c.snapshot.provider, 'OPENAI');
    expect(c.snapshot.region, 'JP');
    expect(c.snapshot.prompt, isFalse);
  });
  test('country uses server default or first supported language', () {
    for (final configuredDefault in ['', 'xx']) {
      final options = translationOptionsFixture();
      final countries = (options['countries'] as List)
          .cast<Map<String, Object?>>();
      final c = TranslationSetupController()
        ..directory(
          ApiTranslationDirectory.decode({
            ...options,
            'countries': [
              for (final country in countries)
                country['countryCode'] == 'CN'
                    ? {...country, 'defaultLanguageCode': configuredDefault}
                    : country,
            ],
          }),
        );
      addTearDown(c.dispose);
      c.country('CN');
      // Server defaults extend the directory language list.
      expect(
        c.snapshot.peer,
        configuredDefault.isEmpty ? 'zh' : configuredDefault,
      );
      c.country('CN', supportedPeerCodes: {'zh', 'en'});
      expect(c.snapshot.peer, 'zh');
      c.country('CN', supportedPeerCodes: {'en', 'fr'});
      expect(c.snapshot.peer, 'en');
      c.country('US');
      expect(c.snapshot.peer, 'en');
    }
  });
  test(
    'contact prefill can preserve current languages; closed controller ignores input',
    () {
      final c = TranslationSetupController();
      c.country('JP', syncPeer: false);
      expect(c.snapshot.peer, 'en');
      c.dispose();
      expect(() {
        c.enable(false);
        c.prompt(false);
        c.language('en', caller: true);
        c.country('US');
        c.provider('OPENAI');
        c.region('JP');
      }, returnsNormally);
    },
  );
}
