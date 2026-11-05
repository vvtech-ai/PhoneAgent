/// OS evidence only. Available does not prove the application's API is reachable.
enum NetworkAvailability { available, unavailable, unknown }

abstract interface class NetworkAvailabilitySource {
  Future<NetworkAvailability> read();
}

enum OnlineEntryDecision {
  available,
  unknown,
  offline,
  simulatedOffline,
  cancelled;

  bool get canAttempt => this == available || this == unknown;
}

/// Web/unsupported platforms must not manufacture positive network evidence.
class UnknownNetworkAvailability implements NetworkAvailabilitySource {
  const UnknownNetworkAvailability();
  @override
  Future<NetworkAvailability> read() async => NetworkAvailability.unknown;
}
