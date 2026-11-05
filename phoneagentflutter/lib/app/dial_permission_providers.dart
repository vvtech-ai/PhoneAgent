import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/dialer/data/device_dial_permission_port.dart';
import '../features/dialer/domain/dial_permission.dart';
import 'business_providers.dart';
import 'app_providers.dart';
import '../features/dialer/data/secure_dial_permission_store.dart';
import '../features/dialer/domain/dial_permission_store.dart';

final dialPermissionPortProvider = Provider<DialPermissionPort>(
  (_) => const DeviceDialPermissionPort(),
);
final dialPermissionStoreProvider = Provider<DialPermissionStore>((ref) {
  final config = ref.watch(appConfigProvider);
  return SecureDialPermissionStore(
    '${config.environment?.name}|${config.apiBaseUri}',
  );
});
final dialPermissionMemoryProvider = Provider<DialPermissionMemory>((ref) {
  ref.watch(loginEpochProvider);
  final memory = DialPermissionMemory(
    store: ref.watch(dialPermissionStoreProvider),
  );
  ref.onDispose(() => memory.generation++);
  return memory;
});
