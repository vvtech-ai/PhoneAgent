import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/presentation/controller/conversation_precheck_controller.dart';
import '../features/conversation/presentation/controller/conversation_state.dart';
import 'business_providers.dart';
import 'developer_network_providers.dart';
import 'online_entry_providers.dart';
import '../features/settings/domain/developer_network_mode.dart';

final conversationPrecheckProvider = ChangeNotifierProvider.autoDispose
    .family<ConversationPrecheckController, ConversationEntry>((ref, entry) {
      ref.watch(loginEpochProvider);
      final controller = ConversationPrecheckController(
        ref.watch(networkAvailabilitySourceProvider),
        ref.watch(networkAvailabilityEventsProvider),
      );
      ref.listen(callModelControllerProvider, (_, model) {
        final blocked =
            !model.loading &&
            (model.error.isNotEmpty || model.catalog?.current == null);
        controller.model(
          ready: !model.loading && model.catalog != null && !blocked,
          blocked: blocked,
          name: model.catalog?.current?.name ?? '实时语音模型',
          error: model.loading
              ? ''
              : model.error.isNotEmpty
              ? model.error
              : model.catalog?.current?.status ?? '',
        );
      }, fireImmediately: true);
      ref.listen(developerNetworkModeProvider, (_, mode) {
        controller.simulateOffline(mode.blocksOnlineEntry);
        controller.simulateWeak(mode == DeveloperNetworkMode.weak);
      }, fireImmediately: true);
      return controller;
    });
