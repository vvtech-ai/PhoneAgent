import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/domain/developer_network_mode.dart';

// Process-local, shared by entries; never persisted as a device/network fact.
final developerNetworkModeProvider = StateProvider<DeveloperNetworkMode>(
  (ref) => DeveloperNetworkMode.normal,
);
