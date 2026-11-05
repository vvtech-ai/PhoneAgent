import '../domain/network_availability.dart';

/// Isolated synthetic OS input. Does not read or change the device's network.
class PreviewNetworkAvailability implements NetworkAvailabilitySource {
  NetworkAvailability value = NetworkAvailability.available;
  bool fail = false;
  int reads = 0;
  @override
  Future<NetworkAvailability> read() async {
    reads++;
    if (fail) throw StateError('Synthetic network sample failure');
    return value;
  }
}
