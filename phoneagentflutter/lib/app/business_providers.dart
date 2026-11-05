import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/account_api.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/call_models/data/api_call_model_repository.dart';
import '../features/call_models/data/api_clone_voice_repository.dart';
import '../features/call_models/domain/clone_voice.dart';
import '../features/call_models/domain/call_models.dart';
import '../features/call_models/presentation/controller/call_model_controller.dart';
import '../features/home/data/dio_home_repository.dart';
import '../features/home/domain/home_config.dart';
import '../features/home/presentation/controller/home_controller.dart';
import 'app_providers.dart';
import 'diagnostics_providers.dart';
import 'request_signing_providers.dart';

// Epoch changes on login/restore/sign-out, not on an access-token refresh.
final loginEpochProvider = Provider<int?>((ref) {
  ref.watch(sessionControllerProvider);
  return ref.read(sessionControllerProvider.notifier).credentials?.epoch;
});
final accountApiProvider = Provider.autoDispose<AccountApi>((ref) {
  ref.watch(loginEpochProvider);
  final api = AccountApi(
    ref.watch(appConfigProvider),
    ref.watch(sessionControllerProvider.notifier),
    diagnostics: ref.watch(diagnosticJournalProvider).record,
    signing: ref.watch(requestSigningProvider),
  );
  ref.onDispose(api.close);
  return api;
});
final homeRepositoryProvider = Provider.autoDispose<HomeRepository>((ref) {
  ref.watch(loginEpochProvider);
  final config = ref.watch(appConfigProvider);
  final repository = DioHomeRepository(
    config,
    SecureHomeLocalStore(
      'home.${config.environment?.name}.${config.apiBaseUri}',
    ),
    signing: ref.watch(requestSigningProvider),
  );
  ref.onDispose(repository.close);
  return repository;
});
final homeControllerProvider =
    StateNotifierProvider.autoDispose<HomeController, HomeState>((ref) {
      ref.watch(loginEpochProvider);
      final controller = HomeController(ref.watch(homeRepositoryProvider));
      controller.refresh();
      return controller;
    });
final callModelRepositoryProvider = Provider.autoDispose<CallModelRepository>(
  (ref) => ApiCallModelRepository(ref.watch(accountApiProvider)),
);
final callModelControllerProvider =
    StateNotifierProvider.autoDispose<CallModelController, CallModelState>((
      ref,
    ) {
      final controller = CallModelController(
        ref.watch(callModelRepositoryProvider),
        cloneRepository: ref.watch(cloneVoiceRepositoryProvider),
      );
      controller.load();
      return controller;
    });

final cloneVoiceRepositoryProvider = Provider.autoDispose<CloneVoiceRepository>(
  (ref) => ApiCloneVoiceRepository(ref.watch(accountApiProvider)),
);
