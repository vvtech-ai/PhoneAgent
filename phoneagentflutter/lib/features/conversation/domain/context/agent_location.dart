class AgentLocation {
  AgentLocation(this.lat, this.lng, {String address = ''})
    : address = address.trim() {
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        (lat == 0 && lng == 0)) {
      throw const FormatException('Invalid location');
    }
  }
  final double lat, lng;
  final String address;
  String get display => address.isNotEmpty
      ? address
      : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  Map<String, Object?> toContext() => {'lat': lat, 'lng': lng};
}

abstract interface class AgentLocationSource {
  /// Never requests authorization. Null means no new usable sample.
  Future<AgentLocation?> read();
  Future<void> cancel();
}
