import '../../domain/conversation_messages.dart';
import '../../domain/conversation_progress.dart';
import '../../domain/agent_protocol.dart';

const batchUnconfirmedNotice = '批量外呼结果尚未确认，请稍后重新进入会话核对。';

enum ConversationPhase {
  ready,
  restoring,
  sending,
  recoveryRequired,
  restoreFailed,
  closed,
}

class ConversationEntry {
  const ConversationEntry({
    required this.sessionId,
    this.title = 'Phone Agent',
    this.restore = false,
    this.skillId,
    this.opening = '',
    this.selectedContact,
    this.ownerEpoch,
  });
  final String sessionId, title, opening;
  final String? skillId;
  final bool restore;
  final SelectedContactContext? selectedContact;
  final int? ownerEpoch;
}

class ConversationState {
  const ConversationState({
    required this.entry,
    this.messages = const [],
    this.phase = ConversationPhase.ready,
    this.voiceMode = true,
    this.preparingCall = false,
    this.activity = '',
    this.notice = '',
    this.transientStatus = '',
    this.activeOptionsId,
    this.pendingToolCallId,
  });
  final ConversationEntry entry;
  final List<ConversationMessage> messages;
  final ConversationPhase phase;
  final bool voiceMode, preparingCall;
  final String activity, notice;

  /// Current local operation feedback; never part of the conversation timeline.
  final String transientStatus;
  final String? activeOptionsId, pendingToolCallId;
  bool get canSend =>
      phase == ConversationPhase.ready &&
      !messages.any(
        (message) =>
            message.transient &&
            message.id.endsWith(':batch-progress') &&
            message.batchReceipt != null,
      );
  ConversationProgress get progress => ConversationProgressPolicy.resolve(
    messages,
    processing: phase == ConversationPhase.sending,
    hasActiveOptions: activeOptionsId != null,
  );
  ConversationState copy({
    List<ConversationMessage>? messages,
    ConversationPhase? phase,
    bool? voiceMode,
    bool? preparingCall,
    String? activity,
    String? notice,
    String? transientStatus,
    String? activeOptionsId,
    String? pendingToolCallId,
    bool clearOptions = false,
  }) => ConversationState(
    entry: entry,
    messages: messages ?? this.messages,
    phase: phase ?? this.phase,
    voiceMode: voiceMode ?? this.voiceMode,
    preparingCall: preparingCall ?? this.preparingCall,
    activity: activity ?? this.activity,
    notice: notice ?? this.notice,
    transientStatus: transientStatus ?? this.transientStatus,
    activeOptionsId: clearOptions
        ? null
        : activeOptionsId ?? this.activeOptionsId,
    pendingToolCallId: clearOptions
        ? null
        : pendingToolCallId ?? this.pendingToolCallId,
  );
}
