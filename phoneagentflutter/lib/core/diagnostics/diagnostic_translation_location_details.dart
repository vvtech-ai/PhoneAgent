/// Bounded country-level diagnostics only; never coordinates or free text.
class DiagnosticTranslationLocationDetails {
  DiagnosticTranslationLocationDetails(Map<String, String> values)
    : values = {
        for (final e in values.entries)
          if (_allowed(e.key, e.value)) e.key: e.value,
      };
  final Map<String, String> values;
  static bool _allowed(String key, String value) {
    if (const {
      'realCountry',
      'effectiveCountry',
      'selectedCountry',
      'snapshotSimulation',
      'currentSimulation',
    }.contains(key)) {
      return value.isEmpty || RegExp(r'^[A-Z]{2}$').hasMatch(value);
    }
    if (const {
      'realStatus',
      'effectiveStatus',
      'selectedStatus',
    }.contains(key)) {
      return const {
        'idle',
        'loading',
        'locating',
        'resolved',
        'denied',
        'blocked',
        'unavailable',
        'failed',
      }.contains(value);
    }
    if (key == 'stage') {
      return const {'entry', 'domesticPreflight'}.contains(value);
    }
    if (key == 'source') return const {'real', 'effective'}.contains(value);
    if (key == 'reason') {
      return const {
        'observed',
        'accepted',
        'loading',
        'locating',
        'missingCountry',
        'nonDomesticCountry',
      }.contains(value);
    }
    if (const {
      'realRefreshing',
      'effectiveRefreshing',
      'selectedRefreshing',
    }.contains(key)) {
      return value == 'true' || value == 'false';
    }
    if (key == 'simulationMatches') return value == 'true' || value == 'false';
    return false;
  }

  Map<String, Object> toJson() => Map<String, Object>.of(values);
  factory DiagnosticTranslationLocationDetails.fromJson(
    Map<String, dynamic> json,
  ) => DiagnosticTranslationLocationDetails({
    for (final e in json.entries)
      if (e.value is String) e.key: e.value as String,
  });
}
