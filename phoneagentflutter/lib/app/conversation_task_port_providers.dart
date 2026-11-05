import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/data/confirmation/api_call_confirmation_reply_repository.dart';
import '../features/conversation/data/confirmation/api_confirmation_supplement_repository.dart';
import '../features/conversation/data/confirmation/secure_confirmation_supplement_store.dart';
import '../features/conversation/data/stopping/api_conversation_stop_repository.dart';
import '../features/conversation/domain/confirmation/call_confirmation_reply.dart';
import '../features/conversation/domain/confirmation/confirmation_supplement.dart';
import '../features/conversation/domain/stopping/conversation_stop.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';
import 'diagnostics_providers.dart';

final callConfirmationReplyRepositoryProvider =
    Provider.autoDispose<CallConfirmationReplyRepository>(
      (ref) =>
          ApiCallConfirmationReplyRepository(ref.watch(accountApiProvider)),
    );
final confirmationSupplementRepositoryProvider =
    Provider.autoDispose<ConfirmationSupplementRepository>(
      (ref) =>
          ApiConfirmationSupplementRepository(ref.watch(accountApiProvider)),
    );
final confirmationSupplementStoreProvider = Provider.autoDispose
    .family<ConfirmationSupplementStore, String>((ref, sessionId) {
      ref.watch(loginEpochProvider);
      final config = ref.watch(appConfigProvider);
      return SecureConfirmationSupplementStore([
        config.environment?.name ?? '',
        '${config.apiBaseUri}',
        ref.watch(currentAccountIdProvider),
        sessionId,
      ]);
    });
final conversationStopRepositoryProvider =
    Provider.autoDispose<ConversationStopRepository>(
      (ref) => ApiConversationStopRepository(
        ref.watch(accountApiProvider),
        ref.watch(currentAccountIdProvider),
        diagnostics: ref.watch(diagnosticJournalProvider).record,
      ),
    );
