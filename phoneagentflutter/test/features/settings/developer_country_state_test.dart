import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_permission_port.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_permission_controller.dart';
import 'package:phone_agent/features/translation/data/preview_translation_location.dart';
import 'package:phone_agent/features/translation/data/secure_translation_preference_store.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import '../translation/translation_preferences_persistence_test.dart';

void main() {
  test(
    'persisted country survives provider recreation and real location refresh',
    () async {
      final store = MemoryTranslationStore()
        ..value = const TranslationPreferences(simulatedCountryIso: 'JP');
      final source = PreviewTranslationLocation()
        ..cached = TrustedTranslationLocation('CN', 100);
      for (var i = 0; i < 2; i++) {
        final container = ProviderContainer(
          overrides: [
            translationPreferenceStoreProvider.overrideWithValue(store),
            translationLocationSourceProvider.overrideWithValue(source),
            translationLocationStoreProvider.overrideWithValue(source),
          ],
        );
        final sub = container.listen(translationAccessProvider, (_, __) {});
        await container.read(translationSetupProvider.notifier).load();
        await container.read(translationLocationProvider.notifier).load();
        expect(container.read(translationAccessProvider).countryIso, 'JP');
        expect(source.cached!.countryIso, 'CN');
        sub.close();
        container.dispose();
      }
      expect(source.requests, 0);
      expect(
        TranslationPreferenceCodec.decode('{"schema":1}').simulatedCountryIso,
        '',
      );
    },
  );
  test(
    'simulation bypasses location permission but preserves call log flow',
    () async {
      final port = PreviewDialPermissionPort();
      var simulated = true, enabled = false;
      final controller = DialPermissionController(
        port: port,
        memory: DialPermissionMemory(),
        simulatedLocation: () => simulated,
        setTranslation: (value) => enabled = value,
        refreshRegion: () => fail('simulation must not refresh GPS'),
        refreshRecent: () {},
      );
      addTearDown(controller.dispose);
      await controller.start(translationEnabled: false);
      expect(port.trace, ['callLog:check', 'callLog:request']);
      await controller.toggle(true);
      expect(enabled, isTrue);
      expect(port.trace.where((v) => v.startsWith('location:')), isEmpty);
      simulated = false;
      await controller.toggle(true);
      expect(controller.snapshot.stage, DialPermissionStage.request);
      expect(port.trace.last, 'location:check');
    },
  );
}
