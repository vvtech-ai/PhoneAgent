import '../domain/translation_location.dart';

/// Explicit synthetic source. Never accesses system services or account data.
class PreviewTranslationLocation
    implements TranslationLocationSource, TranslationLocationStore {
  TranslationLocationResult result = const TranslationLocationResult(
    TranslationLocationStatus.resolved,
    countryIso: 'US',
  );
  TrustedTranslationLocation? cached;
  bool failRead = false, failWrite = false;
  int requests = 0, cancellations = 0, settings = 0;
  @override
  Future<TranslationLocationResult> locate() async {
    requests++;
    final sample = result;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return sample;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }

  @override
  Future<TrustedTranslationLocation?> read() async {
    if (failRead) throw StateError('Synthetic cache read failure');
    return cached;
  }

  @override
  Future<void> write(TrustedTranslationLocation value) async {
    if (failWrite) throw StateError('Synthetic cache write failure');
    cached = value;
  }
}
