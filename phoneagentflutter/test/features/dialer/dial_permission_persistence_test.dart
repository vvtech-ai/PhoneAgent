import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/dial_permission_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('immediate account replacement restores pending prompt flags', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final owner = StateProvider<int>((_) => 1);
    final container = ProviderContainer(
      overrides: [loginEpochProvider.overrideWith((ref) => ref.watch(owner))],
    );
    addTearDown(container.dispose);
    final first = container.read(dialPermissionMemoryProvider);
    await first.ready;
    first.locationShown = true;
    first.locationRequested = true;
    first.callLogRequested = true;
    container.read(owner.notifier).state = 2;
    final restored = container.read(dialPermissionMemoryProvider);
    await restored.ready;
    expect(restored.locationShown, isTrue);
    expect(restored.locationRequested, isTrue);
    expect(restored.callLogRequested, isTrue);
    await first.flushed;
    final reopened = DialPermissionMemory(
      store: container.read(dialPermissionStoreProvider),
    );
    await reopened.ready;
    expect(reopened.callLogRequested, isTrue);
  });

  test('permission prompt flags survive a new app container', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final first = ProviderContainer();
    final memory = first.read(dialPermissionMemoryProvider);
    await memory.ready;
    memory.locationShown = true;
    memory.locationRequested = true;
    memory.callLogRequested = true;
    await memory.flushed;
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final restored = second.read(dialPermissionMemoryProvider);
    await restored.ready;
    expect(restored.locationShown, isTrue);
    expect(restored.locationRequested, isTrue);
    expect(restored.callLogRequested, isTrue);
  });
}
