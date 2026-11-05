import 'call_dialogue.dart';

class ReceiptField {
  const ReceiptField(this.key, this.label, this.value);
  final String key, label, value;
}

class ReceiptBilling {
  const ReceiptBilling({
    required this.sessionId,
    required this.state,
    this.durationSeconds,
    this.connectedDurationMillis,
    this.chargedPoints,
    this.remainingPoints,
    this.firstMinutePoints,
    this.blockDurationMs,
    this.blockPoints,
  });
  final String sessionId, state;
  final int? durationSeconds, chargedPoints, remainingPoints;
  final int? connectedDurationMillis;
  final int? firstMinutePoints, blockDurationMs, blockPoints;

  static ReceiptBilling? parse(Object? value) {
    final data = ReceiptValues.object(value);
    final id = ReceiptValues.text(data, 'billingSessionId');
    if (id.isEmpty) return null;
    int? number(String key) {
      final n = int.tryParse(ReceiptValues.text(data, key));
      return n == null || n < 0 ? null : n;
    }

    return ReceiptBilling(
      sessionId: id,
      state: ReceiptValues.text(data, 'billingState'),
      durationSeconds: number('displayDurationSeconds'),
      connectedDurationMillis: number('connectedDurationMs'),
      chargedPoints: number('chargedPoints'),
      remainingPoints: number('remainingPoints'),
      firstMinutePoints: number('firstMinutePoints'),
      blockDurationMs: number('blockDurationMs'),
      blockPoints: number('blockPoints'),
    );
  }
}

class CallReceipt {
  static const ledgerOutcomeSourceKey = '_ledgerOutcomeSource';

  CallReceipt({
    required this.attemptId,
    this.callId = '',
    this.targetName = '',
    this.phoneNumber = '',
    required this.status,
    this.headline = '',
    this.detail = '',
    this.transcript = '',
    List<ReceiptField> fields = const [],
    this.billing,
    Map<String, String> metadata = const {},
  }) : fields = List.unmodifiable(fields),
       metadata = Map.unmodifiable(metadata);
  final String attemptId,
      callId,
      targetName,
      phoneNumber,
      status,
      headline,
      detail,
      transcript;
  final List<ReceiptField> fields;
  final ReceiptBilling? billing;
  // Retained for semantic status resolution; never rendered as a raw table.
  final Map<String, String> metadata;

  /// v66 single-call cards require recorded dialogue before resolving media.
  String? get recordingCallId {
    if (CallDialogue.parse(transcript).isEmpty ||
        metadata['answered']?.trim().toLowerCase() == 'false') {
      return null;
    }
    final anchor = metadata['callId']?.trim() ?? '';
    final connected = ['connectedDurationMs', 'durationMillis']
        .map((key) => int.tryParse(metadata[key] ?? ''))
        .whereType<int>()
        .firstOrNull;
    return anchor.isNotEmpty && (connected == null || connected > 0)
        ? anchor
        : null;
  }

  factory CallReceipt.fromResult(
    Map<String, Object?> data, {
    bool liveFinalResult = false,
  }) {
    final metadata = ReceiptValues.object(data['metadata']);
    String t(String key) => ReceiptValues.text(data, key);
    String m(String key) => ReceiptValues.text(metadata, key);
    return CallReceipt(
      attemptId: ReceiptValues.first([t('callAttemptId'), m('callAttemptId')]),
      callId: ReceiptValues.first([t('callId'), m('callId')]),
      targetName: ReceiptValues.first([t('targetName'), m('targetName')]),
      phoneNumber: ReceiptValues.first([t('phoneNumber'), m('phoneNumber')]),
      status: t('status'),
      headline: t('headline'),
      detail: t('detail'),
      transcript: ReceiptValues.first([
        m('dialogueTranscript'),
        m('dialogueDetail'),
        m('dialogue'),
        m('transcript'),
        t('transcript'),
        t('detail'),
      ]),
      fields: parseFields(data['receiptFields']),
      billing: ReceiptBilling.parse(data['billingSummary']),
      metadata: {
        for (final key in metadata.keys)
          if (key != 'liveFinalResult' &&
              key != 'physicalTerminalOnly' &&
              key != 'physicalOnlyOutcomePending' &&
              key != ledgerOutcomeSourceKey &&
              m(key).isNotEmpty)
            key: m(key),
        if (t('resultCode').isNotEmpty) 'resultCode': t('resultCode'),
        if (liveFinalResult) 'liveFinalResult': 'true',
      },
    );
  }
  bool get isRunning => const {
    'CALL_REQUESTED',
    'CALL_STARTED',
    'STARTED',
    'CALLING',
    'DIALING',
    'REQUESTED',
    'RINGING',
    'CONNECTED',
    'ENDING',
    'CANCELLING',
    'RESULT_PENDING',
    'PHYSICAL_CLOSED',
    'STOP_ACCEPTED',
    'PRIMARY_CLOSED_FORK_OBSERVING',
    'RUNNING',
  }.contains(status.toUpperCase());

  static List<ReceiptField> parseFields(Object? value) {
    if (value is! List) return const [];
    return List.unmodifiable(
      value
          .map(ReceiptValues.object)
          .map(
            (m) => ReceiptField(
              ReceiptValues.text(m, 'key'),
              ReceiptValues.text(m, 'label'),
              ReceiptValues.text(m, 'value'),
            ),
          )
          .where(
            (f) => f.key.isNotEmpty && f.label.isNotEmpty && f.value.isNotEmpty,
          ),
    );
  }
}

abstract final class ReceiptValues {
  static Map<String, Object?> object(Object? value) =>
      value is Map<String, Object?> ? value : const {};
  static String text(Map<String, Object?> data, String key) {
    final value = data[key];
    return value is String || value is num || value is bool
        ? value.toString().trim()
        : '';
  }

  static String first(Iterable<String> values) =>
      values.firstWhere((v) => v.isNotEmpty, orElse: () => '');
  static String outcome(String value) => switch (value.trim().toUpperCase()) {
    'SUCCESS' || 'COMPLETED' => 'COMPLETED',
    'USER_CANCELLED' || 'CANCELLED' => 'CANCELLED',
    'UNCLEAR' => 'UNCLEAR',
    _ => 'FAILED',
  };
}
