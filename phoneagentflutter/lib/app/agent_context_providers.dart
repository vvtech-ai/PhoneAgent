import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../features/conversation/domain/context/task_location_permission.dart';
import '../features/conversation/data/context/device_agent_clock.dart';
import '../features/conversation/data/tools/device_permission_channel.dart';
import '../features/conversation/domain/context/agent_clock.dart';
import '../features/conversation/domain/context/agent_context_builder.dart';
import '../features/conversation/domain/tools/conversation_permission.dart';
import 'agent_location_providers.dart';
import 'business_providers.dart';
import 'restaurant_memory_providers.dart';

final agentClockSourceProvider = Provider<AgentClockSource>(
  (_) => const DeviceAgentClock(),
);
final conversationPermissionSourceProvider =
    Provider<ConversationPermissionSource>(
      (_) => const DevicePermissionChannel(),
    );
final taskLocationPermissionProvider =
    Provider.autoDispose<TaskLocationPermission>((ref) {
      ref.watch(loginEpochProvider);
      ref.keepAlive(); // Reopening a task must retain this account's denials.
      return TaskLocationPermission(
        ref.watch(conversationPermissionSourceProvider),
      );
    });

bool get needsAndroidTaskLocationPreflight =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
final agentContextBuilderProvider = Provider.autoDispose<AgentContextBuilder>(
  (ref) {
    ref.watch(loginEpochProvider);
    final builder = AgentContextBuilder(
      location: ref.watch(agentLocationProvider.notifier).context,
      clock: ref.watch(agentClockSourceProvider),
      permissions: ref.watch(conversationPermissionSourceProvider),
      memoryContext: () =>
          ref.read(restaurantContactMemoryOfferProvider).context(),
    );
    ref.onDispose(builder.close);
    return builder;
  },
  dependencies: [
    loginEpochProvider,
    agentLocationProvider,
    agentClockSourceProvider,
    conversationPermissionSourceProvider,
    restaurantContactMemoryOfferProvider,
  ],
);
