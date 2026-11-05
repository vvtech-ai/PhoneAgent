import 'dart:async';
import 'apology_voice_providers.dart';
import 'commerce_providers.dart';
import '../features/conversation/domain/recovery/batch_entitlement_refresh_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/domain/confirmation/confirmation_supplement_outbox.dart';
import 'conversation_task_port_providers.dart';
import '../core/network/account_session.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/conversation/data/history/api_conversation_history_repository.dart';
import '../features/conversation/data/history/api_timeline_source.dart';
import '../features/conversation/data/stream/dio_agent_gateway.dart';
import '../features/conversation/data/tools/api_contact_lookup_continuation.dart';
import '../features/conversation/domain/tools/phone_contact_lookup.dart';
import '../features/conversation/domain/tools/name_contact_lookup.dart';
import '../features/conversation/data/tools/api_name_contact_lookup_continuation.dart';
import '../features/contacts/data/device_contact_channel.dart';
import '../features/contacts/data/lpinyin_contact_dictionary.dart';
import '../features/contacts/domain/contact_records.dart';
import '../features/conversation/domain/agent_protocol.dart';
import '../features/conversation/domain/history/conversation_history.dart';
import '../features/conversation/domain/history/ledger_sync.dart';
import '../features/conversation/presentation/controller/conversation_controller.dart';
import '../features/conversation/presentation/controller/conversation_state.dart';
import '../features/tasks/data/api_task_repository.dart';
import '../features/tasks/data/api_task_scene_titles.dart';
import '../features/tasks/domain/task_records.dart';
import '../features/tasks/domain/task_error_status_projection.dart';
import '../features/conversation/domain/recovery/task_error_recovery_session.dart';
import 'task_error_status_providers.dart';
import 'task_draft_cleanup_providers.dart';
import '../features/tasks/presentation/controller/task_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'agent_context_providers.dart';
import 'diagnostics_providers.dart';
import '../core/diagnostics/diagnostic_event.dart';
import 'call_admission_providers.dart';
import 'call_session_providers.dart';
import 'wallet_settlement_providers.dart';
import 'ocr_providers.dart';
import 'attachment_providers.dart';
import 'conversation_task_speech_providers.dart';
import 'task_voice_preference_providers.dart';
import '../features/conversation/presentation/controller/conversation_speech_controller.dart';
import '../features/attachments/presentation/controller/ocr_session_controller.dart';
import '../features/conversation/domain/receipts/conversation_billing_signals.dart';
import '../features/conversation/presentation/controller/detached_batch_streams.dart';

final detachedBatchStreamsProvider = Provider.autoDispose<DetachedBatchStreams>(
  (ref) {
    ref.watch(loginEpochProvider);
    ref.watch(agentGatewayProvider);
    ref.keepAlive();
    final streams = DetachedBatchStreams(
      onFinished: () => ref.invalidate(taskControllerProvider),
    );
    ref.onDispose(streams.close);
    return streams;
  },
);

final deviceContactSourceProvider = Provider<DeviceContactSource>(
  (ref) => const DeviceContactChannel(),
);
final phoneContactLookupProvider = Provider.autoDispose<PhoneContactLookup>(
  (ref) => PhoneContactLookup(
    ref.watch(deviceContactSourceProvider),
    ApiContactLookupContinuation(
      ref.watch(accountApiProvider),
      ref.watch(currentAccountIdProvider),
    ),
  ),
);
final nameContactLookupProvider = Provider.autoDispose<NameContactLookup>(
  (ref) => NameContactLookup(
    ref.watch(deviceContactSourceProvider),
    ApiNameContactLookupContinuation(
      ref.watch(accountApiProvider),
      ref.watch(currentAccountIdProvider),
    ),
    const LpinyinContactDictionary(),
  ),
);

final currentAccountIdProvider = Provider.autoDispose<String>((ref) {
  ref.watch(loginEpochProvider);
  return ref.read(sessionControllerProvider.notifier).credentials?.accountId ??
      (throw ApiFailure.signedOut);
});
final taskRepositoryProvider = Provider.autoDispose<TaskRepository>(
  (ref) => ApiTaskRepository(
    ref.watch(accountApiProvider),
    ref.watch(currentAccountIdProvider),
    sceneTitles: ApiTaskSceneTitles(
      ref.watch(accountApiProvider),
      ref.watch(currentAccountIdProvider),
    ),
  ),
);
final taskControllerProvider =
    StateNotifierProvider.autoDispose<TaskController, TaskState>((ref) {
      final statusSync = ref.watch(taskErrorStatusSyncProvider);
      final drafts = ref.watch(taskDraftAccountStoreProvider);
      final controller = TaskController(
        ref.watch(taskRepositoryProvider),
        beforeRefresh: statusSync.flush,
        afterHide: (row) async {
          final sessionId = row.sessionId;
          if (row.kind == TaskRecordKind.conversation &&
              sessionId != null &&
              sessionId.isNotEmpty) {
            await drafts?.clearTask(sessionId);
          }
        },
        project: (rows) =>
            projectPendingTaskErrors(rows, statusSync.pendingExitSessions),
      );
      final changes = statusSync.changes.listen((_) => controller.reproject());
      ref.onDispose(changes.cancel);
      final recovered = ref
          .watch(taskErrorNetworkRecoveryProvider)
          .completed
          .listen((_) {
            if (controller.mounted) {
              controller.refresh(synchronizeStatus: false);
            }
          });
      ref.onDispose(recovered.cancel);
      controller.refresh();
      return controller;
    });
final historyRepositoryProvider =
    Provider.autoDispose<ConversationHistoryRepository>((ref) {
      final api = ref.watch(accountApiProvider);
      return ApiConversationHistoryRepository(
        api,
        LedgerSync(ApiTimelineSource(api)),
        ref.watch(currentAccountIdProvider),
      );
    });
final agentGatewayProvider = Provider.autoDispose<AgentGateway>((ref) {
  final epoch = ref.watch(loginEpochProvider);
  final session = ref.watch(sessionControllerProvider.notifier);
  final gateway = DioAgentGateway(
    ref.watch(appConfigProvider),
    session,
    diagnostics: ref.watch(diagnosticJournalProvider).record,
    userContextProvider: ref.watch(agentContextBuilderProvider).prepare,
    beforeContext: needsAndroidTaskLocationPreflight
        ? ref.watch(taskLocationPermissionProvider).prepare
        : null,
    api: ref.watch(accountApiProvider),
  );
  final refreshing = BatchEntitlementRefreshGateway(
    gateway,
    refresh: () => ref.invalidate(catalogControllerProvider),
    isCurrent: () => session.credentials?.epoch == epoch,
  );
  ref.onDispose(() {
    refreshing.close();
    gateway.close();
  });
  return refreshing;
});
final conversationControllerProvider = StateNotifierProvider.autoDispose
    .family<ConversationController, ConversationState, ConversationEntry>((
      ref,
      entry,
    ) {
      final epoch = ref.watch(loginEpochProvider);
      final accountSession = ref.read(sessionControllerProvider.notifier);
      ref.watch(taskErrorNetworkRecoveryProvider);
      late final ConversationController controller;
      var controllerReady = false;
      final supplements = ConfirmationSupplementOutbox(
        sessionId: entry.sessionId,
        store: ref.watch(confirmationSupplementStoreProvider(entry.sessionId)),
        repository: ref.watch(confirmationSupplementRepositoryProvider),
        onRecords: (records, failed) =>
            controller.showConfirmationSupplements(records, failed),
      );
      final attachments = OcrSessionController(
        sessionId: entry.sessionId,
        source: ref.watch(ocrImageSourceProvider),
        recognizer: ref.watch(ocrRecognizerProvider),
        repository: ref.watch(ocrRepositoryProvider),
        nextId: newConversationId,
        isCurrent: () =>
            controllerReady &&
            controller.isOpen &&
            accountSession.credentials?.epoch == epoch,
        initialOpening: () => controller.pendingInitialOpening,
        initialSkillId: () => controller.pendingInitialEntry?.skillId,
        selectedContact: () => controller.pendingInitialEntry?.selectedContact,
      );
      controller = ConversationController(
        entry: entry,
        apologyVoice: apologyVoiceDependencies(ref, waitForPrecheck: true),
        accountIsCurrent: () =>
            accountSession.credentials?.epoch == epoch &&
            (entry.ownerEpoch == null || entry.ownerEpoch == epoch),
        taskErrors: TaskErrorRecoverySession(
          entry.sessionId,
          ref.watch(taskErrorStatusSyncProvider),
          isCurrent: () => accountSession.credentials?.epoch == epoch,
        ),
        detachedBatches: ref.watch(detachedBatchStreamsProvider),
        permissions: needsAndroidTaskLocationPreflight
            ? ref
                  .watch(taskLocationPermissionProvider)
                  .forSession(entry.sessionId)
            : ref.watch(conversationPermissionSourceProvider),
        attachments: attachments,
        documents: ref.watch(agentDocumentFactoryProvider)(),
        accountId: ref.watch(currentAccountIdProvider),
        confirmationReplies: ref.watch(callConfirmationReplyRepositoryProvider),
        supplements: supplements,
        stopRepository: ref.watch(conversationStopRepositoryProvider),
        onTaskResultChanged: () => ref.invalidate(taskControllerProvider),
        diagnostics: ref.watch(diagnosticJournalProvider).record,
        gateway: ref.watch(agentGatewayProvider),
        history: ref.watch(historyRepositoryProvider),
        contactLookup: ref.watch(phoneContactLookupProvider),
        nameContactLookup: ref.watch(nameContactLookupProvider),
        callAdmission: ref.watch(callAdmissionProvider(entry.sessionId)),
        callSessions: ref.watch(callSessionRepositoryProvider),
      );
      controllerReady = true;
      bindApologyModelChanges(ref, controller);
      final taskSpeech = ref.watch(conversationTaskSpeechProvider(entry));
      final speechFactory = taskSpeech?.factory;
      final voicePreferences = ref.watch(taskVoicePreferenceProvider.notifier);
      if (speechFactory != null) {
        controller.speech = ConversationSpeechController(
          factory: speechFactory,
          diagnostics: ref.watch(diagnosticJournalProvider).record,
          gateDecision: () {
            if (!voicePreferences.ready) {
              return DiagnosticTtsNarrationDecision.preferenceNotReady;
            }
            if (!voicePreferences.speechEnabled) {
              return DiagnosticTtsNarrationDecision.voiceDisabled;
            }
            if (!controller.isOpen) {
              return DiagnosticTtsNarrationDecision.pageClosed;
            }
            if (accountSession.credentials?.epoch != epoch) {
              return DiagnosticTtsNarrationDecision.accountChanged;
            }
            if (controller.calls?.snapshot.showCall == true ||
                controller.calls?.snapshot.call != null &&
                    controller.calls?.snapshot.call?.snapshot?.isTerminal !=
                        true) {
              return DiagnosticTtsNarrationDecision.callActive;
            }
            return DiagnosticTtsNarrationDecision.gateClosed;
          },
          enabled: () =>
              voicePreferences.ready &&
              voicePreferences.speechEnabled &&
              controller.isOpen &&
              accountSession.credentials?.epoch == epoch &&
              controller.calls?.snapshot.showCall != true &&
              (controller.calls?.snapshot.call == null ||
                  controller.calls?.snapshot.call?.snapshot?.isTerminal ==
                      true),
        );
        final removeSpeechGate = controller.calls?.addListener((call) {
          if (call.showCall) {
            controller.speech?.pauseForCall();
          } else {
            controller.speech?.resumeResult();
          }
        });
        ref.onDispose(() => removeSpeechGate?.call());
        void preferenceChanged() {
          if (!voicePreferences.speechEnabled) {
            unawaited(controller.speech?.interrupt());
          }
        }

        voicePreferences.addListener(preferenceChanged);
        ref.onDispose(() => voicePreferences.removeListener(preferenceChanged));
      }
      final walletSync = ref.watch(walletSettlementSyncProvider);
      var speechInputPending = false;
      final remove = controller.addListener((state) {
        if (state.phase == ConversationPhase.closed) taskSpeech?.close();
        final sending = state.phase == ConversationPhase.sending;
        if (sending && !speechInputPending) taskSpeech?.prepare();
        speechInputPending = sending;
        walletSync.observe(
          ConversationBillingSignals.fromMessages(state.messages),
        );
      });
      ref.onDispose(remove);
      bindApologyPrecheck(ref, controller, entry);
      if (entry.restore) {
        unawaited(controller.restore());
      } else {
        unawaited(supplements.restore());
      }
      return controller;
    });
