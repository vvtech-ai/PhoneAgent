import 'translation_location.dart';
import 'translation_preferences.dart';

/// v65 separates effective model selection from call planning. Forced model
/// selection can be shown without a region; real calls still require one.
class TranslationAccess {
  const TranslationAccess({
    required this.countryIso,
    required this.forced,
    this.loading = false,
  });
  factory TranslationAccess.resolve(
    TranslationLocationState location,
    TranslationPreferences preferences, {
    required bool testControlsEnabled,
  }) => TranslationAccess(
    countryIso: location.trusted?.countryIso,
    loading: location.trusted == null && location.busy,
    forced: testControlsEnabled && preferences.forceBackend,
  );
  final String? countryIso;
  final bool forced, loading;
  bool get overseasLocation => countryIso != null && countryIso != 'CN';
  bool get canSelect => forced || overseasLocation;
  bool get canCall => !loading && countryIso != null && canSelect;
  bool get showOverseasSettings => overseasLocation;
}
