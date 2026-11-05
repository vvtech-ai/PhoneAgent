enum CallModelQuality { good, fair, high, unavailable }

class CallModelReading {
  const CallModelReading.unavailable()
    : latencyMs = null,
      confirmedUnavailable = true;
  const CallModelReading.unknown()
    : latencyMs = null,
      confirmedUnavailable = false;
  CallModelReading.probe({required bool available, required int? latencyMs})
    : latencyMs = available && latencyMs != null && latencyMs >= 0
          ? latencyMs
          : null,
      confirmedUnavailable = !available;
  final int? latencyMs;
  final bool confirmedUnavailable;
  CallModelQuality get quality => latencyMs == null
      ? CallModelQuality.unavailable
      : latencyMs! < 200
      ? CallModelQuality.good
      : latencyMs! < 500
      ? CallModelQuality.fair
      : CallModelQuality.high;
}

abstract interface class CallModelQualityRepository {
  Future<Map<String, CallModelReading>> refresh();
}
