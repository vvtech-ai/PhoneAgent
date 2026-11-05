/// Fixed structural vocabulary; never retain arbitrary server strings.
enum DiagnosticAgentFrame {
  status,
  toolStart,
  toolComplete,
  toolCard,
  signal,
  finalResponse,
  committed,
  error,
  unknown,
}

enum DiagnosticAgentTool {
  search,
  stageReport,
  activateSkill,
  fillUserIdentity,
  reportCallOutcome,
  provideSkillTemplate,
  generateBatchReceiptCsv,
  askUser,
  showOptions,
  requestPermission,
  importDocument,
  confirmBatchTask,
  makeCall,
  makeBatchCalls,
  lookupContact,
  lookupDeviceContactsByNames,
  unknown,
}

enum DiagnosticAgentSignal {
  textReply('TEXT_REPLY'),
  askUser('ASK_USER'),
  showOptions('SHOW_OPTIONS'),
  requestPermission('REQUEST_PERMISSION'),
  importDocument('IMPORT_DOCUMENT_REQUEST'),
  makeCall('MAKE_CALL_REQUEST'),
  lookupContact('LOOKUP_CONTACT_REQUEST'),
  lookupDeviceContactsByNames('LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST'),
  callResult('CALL_RESULT'),
  batchCallResult('BATCH_CALL_RESULT'),
  error('ERROR'),
  unknown('');

  const DiagnosticAgentSignal(this.wireName);
  final String wireName;
  static DiagnosticAgentSignal fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => unknown,
  );
}

enum DiagnosticAgentLedger {
  userTurnAccepted('USER_TURN_ACCEPTED'),
  assistantTurnCommitted('ASSISTANT_TURN_COMMITTED'),
  toolRequested('TOOL_REQUESTED'),
  toolResultRecorded('TOOL_RESULT_RECORDED'),
  callRequested('CALL_REQUESTED'),
  callStarted('CALL_STARTED'),
  callCompleted('CALL_COMPLETED'),
  callFailed('CALL_FAILED'),
  callCancelled('CALL_CANCELLED'),
  callRejected('CALL_REJECTED'),
  callOutcomeReported('CALL_OUTCOME_REPORTED'),
  conversationInterrupted('CONVERSATION_INTERRUPTED'),
  conversationResumed('CONVERSATION_RESUMED'),
  ocrImageCommitted('OCR_IMAGE_COMMITTED'),
  runFailed('RUN_FAILED'),
  runCancelled('RUN_CANCELLED'),
  unknown('');

  const DiagnosticAgentLedger(this.wireName);
  final String wireName;
  static DiagnosticAgentLedger fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => unknown,
  );
}

T _named<T extends Enum>(Iterable<T> values, Object? name, T unknown) =>
    values.firstWhere((value) => value.name == name, orElse: () => unknown);

class DiagnosticAgentDetails {
  const DiagnosticAgentDetails({
    required this.frame,
    this.signal,
    this.tool,
    this.ledger,
    this.sequence,
  });

  final DiagnosticAgentFrame frame;
  final DiagnosticAgentSignal? signal;
  final DiagnosticAgentTool? tool;
  final DiagnosticAgentLedger? ledger;
  final int? sequence;

  static DiagnosticAgentTool toolFromWire(Object? name) =>
      _named(DiagnosticAgentTool.values, name, DiagnosticAgentTool.unknown);

  Map<String, Object> toJson() => {
    'frame': frame.name,
    if (signal != null) 'signal': signal!.name,
    if (tool != null) 'tool': tool!.name,
    if (ledger != null) 'ledger': ledger!.name,
    if (sequence != null && sequence! > 0 && sequence! <= 9007199254740991)
      'sequence': sequence!,
  };

  factory DiagnosticAgentDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticAgentDetails(
        frame: _named(
          DiagnosticAgentFrame.values,
          json['frame'],
          DiagnosticAgentFrame.unknown,
        ),
        signal: json['signal'] == null
            ? null
            : _named(
                DiagnosticAgentSignal.values,
                json['signal'],
                DiagnosticAgentSignal.unknown,
              ),
        tool: json['tool'] == null ? null : toolFromWire(json['tool']),
        ledger: json['ledger'] == null
            ? null
            : _named(
                DiagnosticAgentLedger.values,
                json['ledger'],
                DiagnosticAgentLedger.unknown,
              ),
        sequence: json['sequence'] is int ? json['sequence'] as int : null,
      );
}
