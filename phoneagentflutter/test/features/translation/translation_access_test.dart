import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_access.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/data/secure_translation_preference_store.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'translation_preferences_persistence_test.dart';

void main() {
  test('initial location loading never authorizes calls even when forced', () {
    for (final forced in [false, true]) {
      for (final status in [
        TranslationLocationStatus.loading,
        TranslationLocationStatus.locating,
      ]) {
        final access = TranslationAccess.resolve(
          TranslationLocationState(status: status),
          TranslationPreferences(forceBackend: forced),
          testControlsEnabled: true,
        );
        expect(access.loading, isTrue);
        expect(access.canCall, isFalse);
      }
    }
  });
  test('a trusted region remains usable during its background refresh', () {
    for (final forced in [false, true]) {
      final access = TranslationAccess.resolve(
        TranslationLocationState(
          status: TranslationLocationStatus.resolved,
          trusted: TrustedTranslationLocation('US', 1),
          refreshing: true,
        ),
        TranslationPreferences(forceBackend: forced),
        testControlsEnabled: true,
      );
      expect(access.loading, isFalse);
      expect(access.canCall, isTrue);
    }
  });
  for (final iso in <String?>[null, 'CN', 'US', 'JP']) {
    for (final forced in [false, true]) {
      test(
        'region $iso forced $forced separates selection, call and settings',
        () {
          final state = TranslationLocationState(
            trusted: iso == null ? null : TrustedTranslationLocation(iso, 1),
          );
          final preference = TranslationPreferences(
            forceBackend: forced,
            translationCountry: 'SG',
            region: 'JP',
          );
          final result = TranslationAccess.resolve(
            state,
            preference,
            testControlsEnabled: true,
          );
          expect(result.canSelect, forced || (iso != null && iso != 'CN'));
          expect(result.canCall, iso != null && (forced || iso != 'CN'));
          expect(result.showOverseasSettings, iso != null && iso != 'CN');
          expect(result.countryIso, iso);
          final disabled = TranslationAccess.resolve(
            state,
            preference,
            testControlsEnabled: false,
          );
          expect(disabled.forced, isFalse);
          expect(disabled.canSelect, iso != null && iso != 'CN');
        },
      );
    }
  }
  test('failed refresh retains trusted region just as v65 cache fallback', () {
    final result = TranslationAccess.resolve(
      TranslationLocationState(
        status: TranslationLocationStatus.failed,
        trusted: TrustedTranslationLocation('US', 1),
        cached: true,
      ),
      const TranslationPreferences(),
      testControlsEnabled: true,
    );
    expect(result.canCall, isTrue);
  });
  test(
    'older or malformed force preference is false; boolean survives roundtrip',
    () {
      for (final raw in [
        '{"schema":1}',
        '{"schema":1,"forceBackend":"true"}',
      ]) {
        expect(TranslationPreferenceCodec.decode(raw).forceBackend, isFalse);
      }
      const value = TranslationPreferences(forceBackend: true, region: 'JP');
      final read = TranslationPreferenceCodec.decode(
        TranslationPreferenceCodec.encode(value),
      );
      expect(read.forceBackend, isTrue);
      expect(read.region, 'JP');
    },
  );
  test(
    'formal force toggle persists without changing region/language; read/write failure visible',
    () async {
      final store = MemoryTranslationStore()
        ..value = const TranslationPreferences(region: 'JP', peer: 'fr');
      final controller = TranslationSetupController(store: store);
      addTearDown(controller.dispose);
      controller.forceBackend(true);
      expect(store.writes, isEmpty);
      await controller.load();
      controller.forceBackend(true);
      await Future<void>.delayed(Duration.zero);
      expect(store.value.forceBackend, isTrue);
      expect(store.value.region, 'JP');
      expect(store.value.peer, 'fr');
      store.writeFails = true;
      controller.forceBackend(false);
      await Future<void>.delayed(Duration.zero);
      expect(controller.status.error, contains('尚未保存'));
      store.writeFails = false;
      await controller.save();
      final reopened = TranslationSetupController(store: store);
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.snapshot.forceBackend, isFalse);
    },
  );
}
