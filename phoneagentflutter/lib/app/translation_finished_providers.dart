import 'diagnostics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/translation/data/translation_dtmf_feedback.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/translation/presentation/controller/translation_finished_recorder.dart';
import 'app_call_record_providers.dart';
import 'translation_session_factory.dart';
import 'translation_archive_providers.dart';
import 'wallet_settlement_providers.dart';
import '../features/points/domain/wallet_settlement_sync.dart';

/// Account-owned, not autoDispose: popping a call must not cancel metadata save.
final translationFinishedRecorderProvider =
    StateNotifierProvider<
      TranslationFinishedRecorder,
      TranslationRecordSaveState
    >((ref) {
      final repository = ref.watch(appCallRecordRepositoryProvider);
      final session = ref.watch(sessionControllerProvider.notifier);
      final owner = session.credentials;
      return TranslationFinishedRecorder(
        accountId: owner?.accountId ?? '',
        repository: repository,
        isCurrent: () => owner != null && owner.sameLogin(session.credentials),
      );
    });

final translationSessionFactoryProvider = Provider<TranslationSessionFactory>((
  ref,
) {
  final settlement = ref.watch(walletSettlementSyncProvider);
  var active = true;
  ref.onDispose(() => active = false);
  return TranslationSessionFactory(
    ref.watch(translationFinishedRecorderProvider.notifier),
    archive: ref.watch(translationArchiveProvider.notifier),
    diagnostics: ref.watch(diagnosticJournalProvider).record,
    onDtmfInput: androidTranslationDtmfInputFeedback,
    onFinished: (finished) {
      if (!active) return;
      // This is only a prompt to GET the current wallet, never a charge fact.
      settlement.observe([
        WalletSettlementSignal(
          'translation:${finished.context.clientCallId}',
          'ended',
        ),
      ]);
    },
  );
});
