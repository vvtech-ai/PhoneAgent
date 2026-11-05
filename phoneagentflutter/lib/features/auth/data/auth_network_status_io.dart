import 'dart:io';

/// Only absence of interface addresses confirms offline; DNS failure does not.
Future<bool> isAuthNetworkOffline() async {
  final interfaces = await NetworkInterface.list(includeLoopback: false);
  return interfaces.every((network) => network.addresses.isEmpty);
}
