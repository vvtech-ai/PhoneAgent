import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/settings/data/api_outbound_number_repository.dart';
import '../features/settings/domain/outbound_number.dart';
import '../features/settings/presentation/controller/outbound_number_controller.dart';
import 'business_providers.dart';

final outboundNumberRepositoryProvider =
    Provider.autoDispose<OutboundNumberRepository>((ref) {
      final api = ref.watch(accountApiProvider);
      final account = ref.read(sessionControllerProvider.notifier).credentials;
      return ApiOutboundNumberRepository(api, account?.accountId ?? '');
    });

final outboundNumberProvider =
    StateNotifierProvider.autoDispose<
      OutboundNumberController,
      OutboundNumberState
    >((ref) {
      final controller = OutboundNumberController(
        ref.watch(outboundNumberRepositoryProvider),
      );
      controller.load();
      return controller;
    }, dependencies: [outboundNumberRepositoryProvider]);
