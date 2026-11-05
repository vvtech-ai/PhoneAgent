import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/diagnostics/diagnostic_event.dart';
import '../core/diagnostics/diagnostic_translation_location_details.dart';
import '../features/translation/domain/translation_location.dart';
import '../features/translation/domain/translation_preferences.dart';
import 'diagnostics_providers.dart';
import 'translation_location_providers.dart';
import 'translation_providers.dart';

void recordTranslationLocationPreflight(
  WidgetRef ref,
  TranslationPreferences snapshot, {
  TranslationLocationState? selected,
}) {
  // Diagnostic provider/storage failures must never alter admission.
  try {
    final real = ref.read(translationLocationProvider);
    final effective = ref.read(effectiveTranslationLocationProvider);
    final current = ref.read(translationSetupProvider).value;
    final state = selected ?? effective;
    final reason = selected == null
        ? 'observed'
        : state.trusted == null && state.busy
        ? state.status.name
        : state.trusted == null
        ? 'missingCountry'
        : state.trusted!.countryIso != 'CN'
        ? 'nonDomesticCountry'
        : 'accepted';
    emitDiagnostic(
      ref.read(diagnosticJournalProvider).record,
      DiagnosticEvent(
        operation: DiagnosticOperation.translationLocationPreflight,
        result: selected == null
            ? DiagnosticResult.received
            : reason == 'accepted'
            ? DiagnosticResult.succeeded
            : DiagnosticResult.failed,
        translationLocation: DiagnosticTranslationLocationDetails({
          'stage': selected == null ? 'entry' : 'domesticPreflight',
          'source': selected == null || snapshot.simulatedCountryIso.isNotEmpty
              ? 'effective'
              : 'real',
          'reason': reason,
          'realRefreshing': '${real.refreshing}',
          'effectiveRefreshing': '${effective.refreshing}',
          'selectedRefreshing': '${state.refreshing}',
          'realStatus': real.status.name,
          'realCountry': real.trusted?.countryIso ?? '',
          'effectiveStatus': effective.status.name,
          'effectiveCountry': effective.trusted?.countryIso ?? '',
          'selectedStatus': state.status.name,
          'selectedCountry': state.trusted?.countryIso ?? '',
          'snapshotSimulation': snapshot.simulatedCountryIso,
          'currentSimulation': current.simulatedCountryIso,
          'simulationMatches':
              '${snapshot.simulatedCountryIso == current.simulatedCountryIso}',
        }),
      ),
    );
  } catch (_) {
    /* Diagnostics are best effort. */
  }
}
