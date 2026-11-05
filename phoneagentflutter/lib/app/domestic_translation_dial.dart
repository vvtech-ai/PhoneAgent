import 'translation_location_diagnostics.dart';
import '../features/dialer/domain/dial_country.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/domain/sip/sip_lease.dart';
import '../features/translation/domain/sip/translation_call_plan.dart';
import '../features/translation/domain/translation_call_finished.dart';
import '../features/translation/domain/translation_preferences.dart';
import '../features/translation/presentation/controller/translation_call_controller.dart';
import '../features/translation/presentation/controller/translation_dial_session_binding.dart';
import 'translation_model_selection_providers.dart';
import 'translation_location_providers.dart';

Future<TranslationCallController> createDomesticTranslationDial(
  WidgetRef ref,
  TranslationDialSessionBinding binding, {
  required String rawNumber,
  required String countryIso,
  required String displayName,
  required TranslationPreferences preferences,
  DialCountry? configuredCountry,
  bool allowUnverifiedNumber = false,
}) async {
  final location = ref.read(
    preferences.simulatedCountryIso.isEmpty
        ? translationLocationProvider
        : effectiveTranslationLocationProvider,
  );
  recordTranslationLocationPreflight(ref, preferences, selected: location);
  final model = ref.read(selectedTranslationModelProvider);
  if (location.trusted == null) {
    throw const TranslationPlanFailure('LOCATION_UNAVAILABLE', '主叫所在国家尚未确认');
  }
  if (model == null ||
      model.transport != 'LOCAL_SIP' ||
      !const {'QWEN', 'DOUBAO'}.contains(model.engine)) {
    throw const TranslationPlanFailure(
      'DOMESTIC_SETTINGS_UNAVAILABLE',
      '请先在设置中确认国内翻译模型',
    );
  }
  final create = binding.createDomestic;
  if (create == null) {
    throw const SipLeaseFailure('MODEL_CONFIGURATION_UNAVAILABLE');
  }
  final plan = TranslationCallPlan.resolve(
    location: location.trusted,
    modelId: model.id,
    modelTransport: model.transport,
    allowUnverifiedNumber: allowUnverifiedNumber,
    serverLanguages: true,
    configuredCountry: configuredCountry,
    rawNumber: rawNumber,
    targetCountry: countryIso,
    preferences: preferences,
    domestic: internalDefaultSipPreferences.copy(provider: model.engine),
  );
  return create(
    plan,
    TranslationCallContext.create(
      targetName: displayName,
      countryIso: countryIso,
      allowUnverifiedNumber: allowUnverifiedNumber,
    ),
  );
}
