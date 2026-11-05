import 'history/ledger_event.dart';

enum AgentEventKind {
  text,
  thinking,
  thinkingDone,
  status,
  toolStart,
  toolComplete,
  toolCard,
  signal,
  finalResponse,
  committed,
  error,
  done,
  heartbeat,
  unknown,
}

class AgentEvent {
  const AgentEvent(
    this.kind, {
    this.text = '',
    this.sessionId = '',
    this.payload = const {},
    this.ledger,
    this.eventName = '',
  });
  final AgentEventKind kind;
  final String text, sessionId;
  final String eventName;
  final Map<String, Object?> payload;
  final LedgerEvent? ledger;
}

class AgentCommand {
  const AgentCommand({
    required this.sessionId,
    required this.userId,
    required this.commandId,
    required this.idempotencyKey,
    required this.traceId,
    this.message,
    this.pendingToolCallId,
    this.initialSkillId,
    this.initialOpening,
    this.initialAssistantPrompt,
    this.initialUserSelection,
    this.userContext,
    this.actionId,
    this.actionPayload,
    this.supersedesCommandId,
    this.inputKind,
    this.selectedContact,
    this.callVoiceSelection,
  });
  final String sessionId, userId, commandId, idempotencyKey, traceId;
  final String? message,
      pendingToolCallId,
      initialSkillId,
      initialOpening,
      initialAssistantPrompt,
      initialUserSelection,
      actionId,
      supersedesCommandId,
      inputKind;
  final Map<String, Object?>? userContext, actionPayload;
  final SelectedContactContext? selectedContact;
  final Map<String, Object?>? callVoiceSelection;
  AgentCommand withCallVoiceSelection(
    Map<String, Object?> voice, {
    String? opening,
    String? assistantPrompt,
    String? userSelection,
  }) => AgentCommand(
    sessionId: sessionId,
    userId: userId,
    commandId: commandId,
    idempotencyKey: idempotencyKey,
    traceId: traceId,
    message: message,
    pendingToolCallId: pendingToolCallId,
    initialSkillId: initialSkillId,
    initialOpening: initialSkillId == null
        ? initialOpening
        : opening ?? initialOpening,
    initialAssistantPrompt: initialSkillId == null
        ? initialAssistantPrompt
        : assistantPrompt ?? initialAssistantPrompt,
    initialUserSelection: initialSkillId == null
        ? initialUserSelection
        : userSelection ?? initialUserSelection,
    userContext: userContext,
    actionId: actionId,
    actionPayload: actionId == 'confirm_call'
        ? {...?actionPayload, 'callVoiceSelection': voice}
        : actionPayload,
    supersedesCommandId: supersedesCommandId,
    inputKind: inputKind,
    selectedContact: selectedContact,
    callVoiceSelection: voice,
  );
  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'userId': userId,
    'commandId': commandId,
    'idempotencyKey': idempotencyKey,
    'traceId': traceId,
    'channel': 'voice',
    if (message != null) 'message': message,
    if (inputKind != null) 'inputKind': inputKind,
    if (pendingToolCallId != null) 'pendingToolCallId': pendingToolCallId,
    if (initialSkillId != null) 'initialSkillId': initialSkillId,
    if (initialOpening != null) 'initialOpening': initialOpening,
    if (initialAssistantPrompt != null)
      'initialAssistantPrompt': initialAssistantPrompt,
    if (initialUserSelection != null)
      'initialUserSelection': initialUserSelection,
    if (userContext != null) 'userContext': userContext,
    if (selectedContact != null) 'selectedContact': selectedContact!.toJson(),
    if (actionId != null) 'actionId': actionId,
    if (actionPayload != null) 'actionPayload': actionPayload,
    if (callVoiceSelection != null) 'callVoiceSelection': callVoiceSelection,
    if (supersedesCommandId != null) 'supersedesCommandId': supersedesCommandId,
  };
}

/// v65 SelectedContactTaskContext; consumed by the first accepted user turn.
class SelectedContactContext {
  const SelectedContactContext({required this.name, required this.phone});
  final String name, phone;
  Map<String, Object?> toJson() => {
    'source': 'CONTACT_DETAIL',
    'name': name.trim(),
    'phone': phone.trim(),
  };
}

class AgentRun {
  const AgentRun(this.events, this.cancel);
  final Stream<AgentEvent> events;
  final void Function() cancel;
}

abstract interface class AgentGateway {
  AgentRun start(AgentCommand command);
}

enum AgentTransportFailure {
  unavailable,
  sessionChanged,
  network,
  rejected,
  malformed,
  incomplete,
}
