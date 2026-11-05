import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/data/api_translation_billing_repository.dart';
import '../features/translation/domain/translation_access.dart';
import '../features/translation/domain/translation_billing.dart';
import 'business_providers.dart';
import 'translation_location_providers.dart';
import 'translation_providers.dart';

// Mirrors the fixed v65 BuildConfig default; not the process-local unlock flag.
final translationTestControlsProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'ENABLE_TRANSLATION_WEBRTC_TEST_CONTROLS',
    defaultValue: true,
  ),
);
final translationAccessProvider = Provider.autoDispose<TranslationAccess>(
  (ref) => TranslationAccess.resolve(
    ref.watch(effectiveTranslationLocationProvider),
    ref.watch(translationSetupProvider).value,
    testControlsEnabled: ref.watch(translationTestControlsProvider),
  ),
);
final translationBillingRepositoryProvider =
    Provider.autoDispose<TranslationBillingRepository>(
      (ref) => ApiTranslationBillingRepository(ref.watch(accountApiProvider)),
    );
final translationBillingProvider =
    FutureProvider.autoDispose<Map<String, double>>(
      (ref) => ref.watch(translationBillingRepositoryProvider).load(),
    );
