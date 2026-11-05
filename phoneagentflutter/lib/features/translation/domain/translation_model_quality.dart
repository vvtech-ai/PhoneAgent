enum TranslationQuality { good, fair, high, unavailable }

class TranslationModelSample {
  const TranslationModelSample.unavailable()
    : latencyMs = null,
      quality = TranslationQuality.unavailable;
  TranslationModelSample.reachable(int milliseconds)
    : latencyMs = milliseconds < 0 ? null : milliseconds,
      quality = milliseconds < 0
          ? TranslationQuality.unavailable
          : milliseconds < 200
          ? TranslationQuality.good
          : milliseconds < 500
          ? TranslationQuality.fair
          : TranslationQuality.high;
  final int? latencyMs;
  final TranslationQuality quality;
}

abstract interface class TranslationModelProbe {
  Future<TranslationModelSample> sample(String region);
}
