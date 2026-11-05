import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/translation/data/sip/api_domestic_provider_repository.dart';
import '../features/translation/domain/sip/domestic_provider_catalog.dart';
import '../features/translation/presentation/controller/domestic_translation_settings_controller.dart';
import 'business_providers.dart';
import 'translation_location_providers.dart';

final domesticTranslationSettingsProvider =
    StateNotifierProvider.autoDispose<
      DomesticTranslationSettingsController,
      DomesticTranslationSettingsState
    >((ref) {
      ref.watch(loginEpochProvider);
      final country = ref.watch(
        effectiveTranslationLocationProvider.select(
          (state) => state.trusted?.countryIso,
        ),
      );
      final region = country == 'CN' ? 'DOMESTIC' : 'OVERSEAS';
      final session = ref.watch(sessionControllerProvider.notifier);
      final owner = session.credentials;
      var active = true;
      final controller = DomesticTranslationSettingsController(
        repository: owner == null || country == null
            ? const _SignedOutDomesticProviderRepository()
            : ApiDomesticProviderRepository(
                ref.watch(accountApiProvider),
                region: region,
              ),
        isCurrent: () =>
            active &&
            owner != null &&
            country != null &&
            owner.sameLogin(session.credentials),
      );
      ref.onDispose(() {
        active = false;
      });
      controller.load();
      return controller;
    });

class _SignedOutDomesticProviderRepository
    implements DomesticProviderRepository {
  const _SignedOutDomesticProviderRepository();
  @override
  Future<DomesticProviderCatalog> load() =>
      Future.error(StateError('Domestic account unavailable'));
  @override
  Future<DomesticProviderCatalog> select(String wireId) => load();
}
