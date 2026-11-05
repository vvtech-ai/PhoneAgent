import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/domain/translation_language_policy.dart';
import 'package:phone_agent/features/translation/domain/translation_preference_store.dart';
import 'package:phone_agent/features/translation/data/secure_translation_preference_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import '../../support/translation_directory_fixture.dart';

class _Store implements TranslationPreferenceStore {
  _Store(this.value);
  TranslationPreferences value;
  @override
  Future<TranslationPreferences> read() async => value;
  @override
  Future<void> write(TranslationPreferences next) async => value = next;
}

Map<String, Object?> _options() {
  final dto = translationOptionsFixture();
  dto['countries'] = [
    for (final country
        in (dto['countries'] as List).cast<Map<String, Object?>>())
      country['countryCode'] == 'JP'
          ? {...country, 'dialCode': '+81', 'defaultLanguageCode': 'ja'}
          : country['countryCode'] == 'SG'
          ? {...country, 'dialCode': '+65'}
          : country,
  ];
  return dto;
}

final _directory = ApiTranslationDirectory.decode(_options());

TranslationDirectory restrictedDirectory({
  List<String> targets = const ['en'],
}) {
  final dto = _options();
  dto['models'] = [
    for (final model in (dto['models'] as List).cast<Map<String, Object?>>())
      model['modelId'] == 'GEMINI'
          ? {
              ...model,
              'sourceLanguageCodes': ['zh'],
              'targetLanguageCodes': targets,
            }
          : model,
  ];
  return ApiTranslationDirectory.decode(dto);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'fresh storage leaves caller unset for located country default',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(
        (await const SecureTranslationPreferenceStore(
          'fresh-alignment',
        ).read()).caller,
        '',
      );
    },
  );

  test(
    'persisting unrelated preferences preserves unset caller across reopen',
    () {
      final saved = TranslationPreferenceCodec.encode(
        const TranslationPreferences(caller: '', prompt: false),
      );
      expect(TranslationPreferenceCodec.decode(saved).caller, '');
    },
  );

  test(
    'first caller follows caller country even after directory loads first',
    () async {
      final setup = TranslationSetupController(
        store: _Store(const TranslationPreferences(caller: '')),
      );
      addTearDown(setup.dispose);
      setup.directory(_directory);
      await setup.load();
      setup.directory(_directory, callerCountryIso: 'US', overseas: true);
      expect(setup.snapshot.caller, 'en');
      expect(
        setup.snapshot.peer,
        'en',
        reason: 'Keep a valid selected peer when caller location arrives',
      );
      setup.language('ja', caller: true);
      setup.directory(_directory, callerCountryIso: 'CN', overseas: false);
      expect(setup.snapshot.caller, 'ja');
    },
  );

  test(
    'caller country received before load respects saved user language',
    () async {
      final setup = TranslationSetupController(
        store: _Store(const TranslationPreferences(caller: 'fr')),
      );
      addTearDown(setup.dispose);
      setup.directory(_directory, callerCountryIso: 'US', overseas: true);
      await setup.load();
      expect(setup.snapshot.caller, 'fr');
    },
  );

  test('manual peer survives first delayed caller location', () async {
    final setup = TranslationSetupController(
      store: _Store(const TranslationPreferences(caller: '')),
    )..directory(_directory);
    addTearDown(setup.dispose);
    await setup.load();
    setup.language('ja', caller: false);
    setup.directory(_directory, callerCountryIso: 'US', overseas: true);
    expect(setup.snapshot.caller, 'en');
    expect(setup.snapshot.peer, 'ja');
  });

  test(
    'directory without caller location keeps fresh caller unset in storage',
    () async {
      final store = _Store(const TranslationPreferences(caller: ''));
      final setup = TranslationSetupController(store: store)
        ..directory(_directory);
      addTearDown(setup.dispose);
      await setup.load();
      await Future<void>.delayed(Duration.zero);
      expect(store.value.caller, '');
    },
  );

  test('history ignores saved peer and reapplies number country default', () {
    final setup = TranslationSetupController()..directory(_directory);
    addTearDown(setup.dispose);
    setup.restoreHistory(
      countryIso: 'JP',
      callerLanguage: 'fr',
      peerLanguage: 'fr',
    );
    expect(setup.snapshot.caller, 'fr');
    expect(setup.snapshot.peer, 'ja');
  });

  for (final domestic in [false, true]) {
    test(
      'CN country default survives active model normalization domestic=$domestic',
      () {
        final setup = TranslationSetupController()
          ..directory(_directory, callerCountryIso: 'CN', overseas: !domestic)
          ..selectModel(
            domestic ? 'QWEN_OMNI_PLUS' : 'GEMINI',
            domestic ? 'QWEN' : 'GEMINI',
            overseas: !domestic,
          )
          ..country('US');
        addTearDown(setup.dispose);
        expect(setup.snapshot.peer, 'en');
        setup.country('CN');
        expect(setup.snapshot.caller, 'zh');
        expect(setup.snapshot.peer, 'zh');
        setup.language('fr', caller: false);
        setup.directory(
          _directory,
          callerCountryIso: 'CN',
          overseas: !domestic,
        );
        expect(setup.snapshot.peer, 'fr');
        setup.country('CN', syncPeer: false);
        expect(setup.snapshot.peer, 'fr');
        setup.restoreHistory(
          countryIso: 'CN',
          callerLanguage: 'zh',
          peerLanguage: 'en',
        );
        expect(setup.snapshot.peer, 'zh');
      },
    );
  }

  test('model selection normalizes both language directions', () {
    final setup = TranslationSetupController()
      ..directory(restrictedDirectory());
    addTearDown(setup.dispose);
    setup.language('fr', caller: true);
    setup.language('ja', caller: false);
    setup.selectModel('GEMINI', 'GEMINI', overseas: true);
    expect(setup.snapshot.caller, 'zh');
    expect(setup.snapshot.peer, 'en');
  });

  test(
    'empty model language lists remain unrestricted like call admission',
    () {
      final dto = _options();
      dto['models'] = [
        for (final model
            in (dto['models'] as List).cast<Map<String, Object?>>())
          {
            ...model,
            'sourceLanguageCodes': <String>[],
            'targetLanguageCodes': <String>[],
          },
      ];
      final setup = TranslationSetupController()
        ..directory(ApiTranslationDirectory.decode(dto));
      addTearDown(setup.dispose);
      setup.selectModel('GEMINI', 'GEMINI', overseas: true);
      expect(setup.snapshot.caller, 'zh');
      expect(setup.snapshot.peer, 'en');
      setup.country('CN');
      expect(setup.snapshot.caller, 'zh');
      expect(setup.snapshot.peer, 'zh');
    },
  );

  test('country selection reapplies active model directions', () {
    final setup = TranslationSetupController()
      ..directory(restrictedDirectory());
    addTearDown(setup.dispose);
    setup.selectModel('GEMINI', 'GEMINI', overseas: true);
    setup.language('fr', caller: true);
    setup.country('JP');
    expect(setup.snapshot.caller, 'zh');
    expect(setup.snapshot.peer, 'en');
  });

  test(
    'history country default remains constrained by active model directions',
    () {
      final setup = TranslationSetupController()
        ..directory(restrictedDirectory());
      addTearDown(setup.dispose);
      setup.selectModel('GEMINI', 'GEMINI', overseas: true);
      setup.restoreHistory(
        countryIso: 'JP',
        callerLanguage: 'fr',
        peerLanguage: 'fr',
      );
      expect(setup.snapshot.caller, 'zh');
      expect(setup.snapshot.peer, 'en');
    },
  );

  test('directory refresh reapplies selected model language support', () {
    final setup = TranslationSetupController()..directory(_directory);
    addTearDown(setup.dispose);
    setup.selectModel('GEMINI', 'GEMINI', overseas: true);
    setup.language('fr', caller: true);
    setup.language('ja', caller: false);
    setup.directory(restrictedDirectory());
    expect(setup.snapshot.caller, 'zh');
    expect(setup.snapshot.peer, 'en');
  });

  test('model change preserves supported manual equal languages', () {
    final setup = TranslationSetupController()
      ..directory(restrictedDirectory(targets: ['zh', 'en']));
    addTearDown(setup.dispose);
    setup.language('zh', caller: false);
    setup.selectModel('GEMINI', 'GEMINI', overseas: true);
    expect(setup.snapshot.caller, 'zh');
    expect(setup.snapshot.peer, 'zh');
  });

  test('missing or invalid peer fallback avoids caller when possible', () {
    for (final peer in ['', 'invalid']) {
      final pair = normalizeTranslationLanguages(
        enabledCodes: ['zh', 'en'],
        caller: 'zh',
        peer: peer,
        defaultCaller: 'zh',
        defaultPeer: 'zh',
      );
      expect(pair.caller, 'zh');
      expect(pair.peer, 'en');
    }
  });
}
