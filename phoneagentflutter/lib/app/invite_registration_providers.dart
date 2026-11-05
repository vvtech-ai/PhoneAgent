import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/invite/domain/invite_store.dart';
import '../features/invite/domain/invite_link_policy.dart';
import '../features/invite/domain/invite_environment_policy.dart';
import 'package:flutter/foundation.dart';
import '../features/invite/domain/invite.dart';
import '../features/invite/data/secure_invite_store.dart';
import '../features/invite/data/api_invite_repository.dart';
import '../features/invite/presentation/controller/pending_invite_controller.dart';
import 'app_providers.dart';
import 'diagnostics_providers.dart';

final inviteStoreProvider = Provider<InviteStore>((ref) {
  final config = ref.watch(appConfigProvider);
  return SecureInviteStore('${config.environment?.name}|${config.apiBaseUri}');
});
final inviteLinkPolicyProvider = Provider<InviteLinkPolicy>((ref) {
  return invitePolicyFor(
    ref.watch(appConfigProvider),
    android: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  );
});
final inviteResolverProvider = Provider<InviteResolver>((ref) {
  final resolver = PublicInviteResolver(
    ref.watch(appConfigProvider),
    diagnostics: () => ref.read(diagnosticJournalProvider).record,
  );
  ref.onDispose(resolver.close);
  return resolver;
});
final pendingInviteProvider =
    StateNotifierProvider<PendingInviteController, PendingInvite>((ref) {
      final controller = PendingInviteController(
        ref.watch(inviteStoreProvider),
      );
      controller.initialize();
      return controller;
    });
