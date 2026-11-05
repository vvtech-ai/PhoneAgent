import 'dart:async';
import 'package:flutter/services.dart';
import '../domain/network_availability.dart';
import '../domain/network_availability_events.dart';

class DeviceNetworkAvailability
    implements NetworkAvailabilitySource, NetworkAvailabilityEvents {
  static final Expando<Stream<NetworkAvailability>> _sharedWatches =
      Expando<Stream<NetworkAvailability>>('network availability watch');

  const DeviceNetworkAvailability({
    this.channel = const MethodChannel('phone_agent/network_availability'),
    this.events = const EventChannel('phone_agent/network_availability_events'),
  });
  final MethodChannel channel;
  final EventChannel events;

  @override
  Stream<NetworkAvailability> watch() => _sharedWatches[this] ??= events
      .receiveBroadcastStream()
      .transform(
        StreamTransformer<Object?, NetworkAvailability>.fromHandlers(
          handleData: (value, sink) => sink.add(_decode(value)),
          handleError: (_, __, sink) => sink.add(NetworkAvailability.unknown),
        ),
      )
      .distinct();

  static NetworkAvailability _decode(Object? value) => switch (value) {
    'available' => NetworkAvailability.available,
    'unavailable' => NetworkAvailability.unavailable,
    _ => NetworkAvailability.unknown,
  };

  @override
  Future<NetworkAvailability> read() async {
    try {
      final value = await channel.invokeMethod<Object?>('read');
      return _decode(value);
    } catch (_) {
      return NetworkAvailability.unknown;
    }
  }
}
