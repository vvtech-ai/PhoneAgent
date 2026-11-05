import 'network_availability.dart';

/// OS network transitions, not backend reachability or permission to retry calls.
abstract interface class NetworkAvailabilityEvents {
  Stream<NetworkAvailability> watch();
}

class NoNetworkAvailabilityEvents implements NetworkAvailabilityEvents {
  const NoNetworkAvailabilityEvents();
  @override
  Stream<NetworkAvailability> watch() => const Stream.empty();
}
