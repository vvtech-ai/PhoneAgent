import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/data/context/device_agent_location.dart';
import '../features/conversation/domain/context/agent_location.dart';
import '../features/conversation/presentation/controller/agent_location_controller.dart';
import 'business_providers.dart';

final agentLocationSourceProvider = Provider.autoDispose<AgentLocationSource>((
  ref,
) {
  ref.watch(loginEpochProvider);
  return DeviceAgentLocation();
}, dependencies: [loginEpochProvider]);

final agentLocationProvider =
    StateNotifierProvider.autoDispose<AgentLocationController, AgentLocation?>((
      ref,
    ) {
      ref.watch(loginEpochProvider);
      ref.keepAlive(); // Account lifetime, not settings-page or conversation lifetime.
      return AgentLocationController(ref.watch(agentLocationSourceProvider));
    }, dependencies: [agentLocationSourceProvider, loginEpochProvider]);
