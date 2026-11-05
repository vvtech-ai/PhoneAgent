import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_preference_store.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import '../../support/translation_directory_fixture.dart';

class HistoryStore implements TranslationPreferenceStore {
  TranslationPreferences value = const TranslationPreferences(
    caller: 'fr',
    peer: 'fr',
    prompt: false,
    domesticModelId: 'DOUBAO',
    overseasModelId: 'OPENAI',
    provider: 'OPENAI',
  );
  final writes = <TranslationPreferences>[];
  @override
  Future<TranslationPreferences> read() async => value;
  @override
  Future<void> write(TranslationPreferences next) async {
    value = next;
    writes.add(next);
  }
}

void main() {
  for (final enabled in [true, false]) {
    for (final (peer, expected) in [
      ('fr', 'en'),
      ('', 'en'),
      ('removed', 'en'),
    ]) {
      for (final caller in ['ja', '', 'removed']) {
        test(
          'history mode=$enabled caller=$caller peer=$peer restores atomically',
          () async {
            final store = HistoryStore();
            final setup = TranslationSetupController(store: store);
            addTearDown(setup.dispose);
            await setup.load();
            setup.directory(syntheticTranslationDirectory);
            setup.enable(enabled);
            await Future<void>.delayed(Duration.zero);
            store.writes.clear();
            setup.restoreHistory(
              countryIso: 'JP',
              callerLanguage: caller,
              peerLanguage: peer,
            );
            final result = setup.snapshot;
            expect(result.enabled, enabled);
            expect(result.country, 'JP');
            expect(
              enabled ? result.normalCountry : result.translationCountry,
              'CN',
            );
            expect(result.caller, caller == 'ja' ? 'ja' : 'fr');
            // The number country's default overrides historical peer language.
            expect(result.peer, expected);
            expect(result.prompt, isFalse);
            expect(result.domesticModelId, 'DOUBAO');
            expect(result.overseasModelId, 'OPENAI');
            expect(result.provider, 'OPENAI');
            await Future<void>.delayed(Duration.zero);
            expect(store.writes, [same(result)]);
            final reloaded = TranslationSetupController(store: store);
            addTearDown(reloaded.dispose);
            await reloaded.load();
            expect(reloaded.snapshot.caller, result.caller);
            expect(reloaded.snapshot.peer, result.peer);
            expect(reloaded.snapshot.country, 'JP');
          },
        );
      }
    }
  }
  test('same country selection resets manually changed peer', () {
    final setup = TranslationSetupController()
      ..directory(syntheticTranslationDirectory);
    addTearDown(setup.dispose);
    setup.country('JP');
    setup.language('fr', caller: false);
    setup.restoreHistory(countryIso: 'JP', callerLanguage: 'ja');
    expect(setup.snapshot.peer, 'en');
  });
  for (final enabled in [false, true]) {
    test('same country histories recompute peer in mode=$enabled', () {
      final setup = TranslationSetupController()
        ..directory(syntheticTranslationDirectory)
        ..enable(enabled);
      addTearDown(setup.dispose);
      for (final (history, expected) in [
        ('fr', 'en'),
        ('ja', 'en'),
        ('', 'en'),
        ('removed', 'en'),
      ]) {
        setup.restoreHistory(
          countryIso: 'JP',
          callerLanguage: 'ja',
          peerLanguage: history,
        );
        expect(setup.snapshot.peer, expected);
        expect(setup.snapshot.enabled, enabled);
      }
    });
    for (final (supported, expected) in [
      ({'en', 'ja'}, 'en'),
      ({'ja', 'zh'}, 'zh'),
      ({'removed'}, ''),
      (<String>{}, ''),
    ]) {
      test('history model filter $supported mode=$enabled', () {
        final setup = TranslationSetupController()
          ..directory(syntheticTranslationDirectory)
          ..enable(enabled);
        addTearDown(setup.dispose);
        setup.restoreHistory(
          countryIso: 'JP',
          callerLanguage: 'ja',
          peerLanguage: 'fr',
          supportedPeerCodes: supported,
        );
        expect(setup.snapshot.peer, expected);
      });
    }
  }
  test('history leaves peer empty when directory offers no languages', () {
    final setup = TranslationSetupController()
      ..directory(
        const TranslationDirectory(
          version: 1,
          countries: [],
          models: [],
          languages: [],
        ),
      );
    addTearDown(setup.dispose);
    setup.restoreHistory(
      countryIso: 'JP',
      callerLanguage: '',
      peerLanguage: 'fr',
    );
    expect(setup.snapshot.peer, '');
  });
  test('history and country selection share offline default rules', () {
    final setup = TranslationSetupController();
    addTearDown(setup.dispose);
    for (final iso in ['CN', 'US', 'JP']) {
      setup.country(iso);
      final expected = setup.snapshot.peer;
      setup.language('fr', caller: false);
      setup.restoreHistory(countryIso: iso, callerLanguage: '');
      expect(setup.snapshot.peer, expected);
    }
  });
}
