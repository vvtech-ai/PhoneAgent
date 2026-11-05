import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/data/drafts/secure_task_draft_repository.dart';
import '../features/conversation/domain/drafts/task_draft.dart';
import '../features/conversation/presentation/controller/task_draft_controller.dart';
import '../features/conversation/presentation/controller/conversation_state.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';

final taskDraftRepositoryProvider = Provider.autoDispose
    .family<TaskDraftRepository, ConversationEntry>((ref, entry) {
      ref.watch(loginEpochProvider);
      final config = ref.watch(appConfigProvider);
      return SecureTaskDraftRepository([
        config.environment?.name ?? '',
        '${config.apiBaseUri}',
        ref.watch(currentAccountIdProvider),
        entry.sessionId,
      ]);
    });

final taskDraftProvider = Provider.autoDispose
    .family<TaskDraftController, ConversationEntry>((ref, entry) {
      ref.watch(loginEpochProvider);
      final conversation = ref.watch(
        conversationControllerProvider(entry).notifier,
      );
      String? pending(String text) {
        final state = ref.read(conversationControllerProvider(entry));
        if (conversation.pendingConfirmationText == text) {
          return 'awaiting-input';
        }
        if (state.phase != ConversationPhase.sending) return null;
        return state.messages
                .where(
                  (m) =>
                      m.transient &&
                      m.role.name == 'user' &&
                      m.text.trim() == text.trim(),
                )
                .lastOrNull
                ?.commandId ??
            'awaiting-input';
      }

      Set<String> accepted() => {
        ...conversation.acceptedInputCommands,
        ...conversation.ledgerFacts
            .where((e) => e.type == 'USER_TURN_ACCEPTED')
            .map((e) => e.commandId)
            .whereType<String>()
            .toSet(),
      };

      final draft = TaskDraftController(
        ref.watch(taskDraftRepositoryProvider(entry)),
        notice: conversation.showNotice,
        pendingCommand: pending,
        acceptedCommandsBeforeSend: accepted,
      );
      ref.listen(conversationControllerProvider(entry), (_, state) {
        draft.observe(
          accepted(),
          state.phase == ConversationPhase.recoveryRequired ||
              (state.phase == ConversationPhase.ready &&
                  state.notice.isNotEmpty &&
                  conversation.pendingConfirmationText == null &&
                  !state.messages.any(
                    (m) =>
                        m.role.name == 'user' &&
                        m.id.startsWith('confirmation-supplement:') &&
                        m.text == draft.submittedText,
                  )) ||
              state.notice.startsWith('上次输入状态尚未同步'),
          nextCommand: draft.submittedText == null
              ? null
              : state.messages
                        .where(
                          (m) =>
                              m.role.name == 'user' &&
                              !m.id.startsWith('confirmation-supplement:') &&
                              m.text.trim() == draft.submittedText!.trim(),
                        )
                        .lastOrNull
                        ?.commandId ??
                    pending(draft.submittedText!),
          settled:
              state.phase == ConversationPhase.ready &&
              conversation.pendingConfirmationText == null,
        );
      });
      ref.onDispose(draft.dispose);
      unawaited(draft.load());
      return draft;
    });
