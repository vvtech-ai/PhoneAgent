enum TranslationLocationStatus {
  idle,
  loading,
  locating,
  resolved,
  denied,
  blocked,
  unavailable,
  failed,
}

class TrustedTranslationLocation {
  TrustedTranslationLocation(String iso, this.sampledAtMs)
    : countryIso = iso.trim().toUpperCase() {
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryIso) || sampledAtMs <= 0) {
      throw const FormatException('Invalid trusted location');
    }
  }
  final String countryIso;
  final int sampledAtMs;
}

class TranslationLocationResult {
  const TranslationLocationResult(this.status, {this.countryIso});
  final TranslationLocationStatus status;
  final String? countryIso;
}

abstract interface class TranslationLocationSource {
  /// User-initiated only. May present a system authorization prompt.
  Future<TranslationLocationResult> locate();
  Future<void> openSettings();
  Future<void> cancel();
}

abstract interface class TranslationLocationStore {
  Future<TrustedTranslationLocation?> read();
  Future<void> write(TrustedTranslationLocation value);
}

class TranslationLocationState {
  const TranslationLocationState({
    this.status = TranslationLocationStatus.idle,
    this.trusted,
    this.cached = false,
    this.refreshing = false,
    this.error = '',
  });
  final TranslationLocationStatus status;
  final TrustedTranslationLocation? trusted;
  final bool cached;
  final bool refreshing;
  final String error;
  bool get busy =>
      refreshing ||
      status == TranslationLocationStatus.loading ||
      status == TranslationLocationStatus.locating;
}
