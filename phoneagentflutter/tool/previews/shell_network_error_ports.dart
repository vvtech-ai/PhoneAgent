import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';

final shellNetworkErrorPortsProvider = Provider<ShellNetworkErrorPorts>((ref) {
  ref.watch(loginEpochProvider);
  final ports = ShellNetworkErrorPorts();
  ref.onDispose(ports.close);
  return ports;
});

/// Isolated MOCK server/network evidence; never changes the OS network.
class ShellNetworkErrorPorts extends PreviewTaskErrorStatusPorts
    implements NetworkAvailabilityEvents {
  final revision = ValueNotifier(0);
  final _network = StreamController<NetworkAvailability>.broadcast();
  bool _closed = false;

  void setOnline(bool online) {
    if (_closed) return;
    offline = !online;
    _network.add(
      online ? NetworkAvailability.available : NetworkAvailability.unavailable,
    );
    revision.value++;
  }

  @override
  Stream<NetworkAvailability> watch() async* {
    yield offline
        ? NetworkAvailability.unavailable
        : NetworkAvailability.available;
    yield* _network.stream;
  }

  @override
  Future<String> send(TaskErrorStatusCommand command) async {
    try {
      return await super.send(command);
    } finally {
      if (!_closed) revision.value++;
    }
  }

  void close() {
    _closed = true;
    unawaited(_network.close());
    revision.dispose();
  }
}
