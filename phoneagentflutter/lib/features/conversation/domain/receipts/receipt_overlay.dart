import '../conversation_messages.dart';
import 'call_receipt.dart';
import 'call_dialogue.dart';

/// Display-only promotion/enrichment matching the current native projector.
/// Ledger status/order stays authoritative; missing same-call media is retained.
abstract final class ReceiptOverlay {
  static bool matches(ConversationMessage a, ConversationMessage b) {
    if (a.batchReceipt != null && b.batchReceipt != null) {
      final left = a.batchReceipt!, right = b.batchReceipt!;
      if (left.explicitId.isNotEmpty || right.explicitId.isNotEmpty) {
        return left.explicitId.isNotEmpty &&
            left.explicitId == right.explicitId;
      }
      return left.isExecutionError &&
          right.isExecutionError &&
          left.items.isEmpty &&
          right.items.isEmpty &&
          (a.commandId?.isNotEmpty ?? false) &&
          a.commandId == b.commandId;
    }
    if (a.receipt == null || b.receipt == null) return false;
    final left = a.receipt!, right = b.receipt!;
    if (left.status.trim().toUpperCase() == 'EXECUTION_ERROR' &&
        right.status.trim().toUpperCase() == 'EXECUTION_ERROR' &&
        left.callId.isEmpty &&
        right.callId.isEmpty &&
        (left.attemptId.startsWith('unidentified:') ||
            right.attemptId.startsWith('unidentified:')) &&
        (a.commandId?.isNotEmpty ?? false) &&
        a.commandId == b.commandId) {
      return true;
    }
    if (left.attemptId.isNotEmpty && right.attemptId.isNotEmpty) {
      String identity(CallReceipt receipt) =>
          receipt.callId.isNotEmpty &&
              receipt.attemptId == 'call:${receipt.callId}'
          ? receipt.callId
          : receipt.attemptId;
      return identity(left) == identity(right);
    }
    return left.callId.isNotEmpty && left.callId == right.callId;
  }

  static ConversationMessage promote(
    ConversationMessage fact,
    ConversationMessage live,
  ) {
    // A committed batch result can be PENDING while its execution has ended.
    // Its item states, not the batch status word, decide whether it is final.
    if (fact.batchReceipt != null && live.batchReceipt != null) {
      final factSequence = fact.batchReceipt!.resultSequence;
      final liveSequence = live.batchReceipt!.resultSequence;
      if (factSequence > 0 && liveSequence > 0) {
        if (liveSequence > factSequence) {
          return ConversationMessage(
            id: fact.id,
            role: fact.role,
            text: fact.text,
            commandId: fact.commandId,
            toolCallId: fact.toolCallId,
            transient: true,
            batchReceipt: live.batchReceipt,
          );
        }
        return fact;
      }
      if (!fact.batchReceipt!.isRunning) return fact;
    }
    if (_terminal(_status(fact)) &&
        _terminal(_status(live)) &&
        fact.receipt != null &&
        live.receipt != null &&
        matches(fact, live)) {
      return _enrich(fact, live);
    }
    final progress =
        live.batchReceipt != null && live.id.endsWith(':batch-progress');
    if ((!_terminal(_status(live)) && !progress) || _terminal(_status(fact))) {
      return fact;
    }
    return ConversationMessage(
      id: fact.id,
      role: fact.role,
      text: fact.text,
      commandId: fact.commandId,
      toolCallId: fact.toolCallId,
      options: fact.options,
      transient: true,
      receipt: live.receipt,
      batchReceipt: live.batchReceipt,
    );
  }

  static ConversationMessage _enrich(
    ConversationMessage fact,
    ConversationMessage live,
  ) {
    final a = fact.receipt!, b = live.receipt!;
    if (a.callId.isNotEmpty && b.callId.isNotEmpty && a.callId != b.callId) {
      return fact;
    }
    final durableOutcome =
        a.metadata['agentOutcome']?.trim().toUpperCase() ?? '';
    final durableCommitted = a.metadata['committedCallResult'] == 'true';
    final durableBusinessUnclear = durableOutcome == 'UNCLEAR';
    final liveStatus = b.status.trim().toUpperCase();
    final liveOutcome = b.metadata['agentOutcome']?.trim().toUpperCase() ?? '';
    final hasReportedOutcome = durableOutcome.isNotEmpty;
    final trustedLiveFinal = b.metadata['liveFinalResult'] == 'true';
    final promoteTrustedLive =
        a.metadata['physicalTerminalOnly'] == 'true' &&
        trustedLiveFinal &&
        !const {'CALL_COMPLETED', 'ENDED'}.contains(liveStatus);
    final hasLiveOutcome =
        liveOutcome.isNotEmpty ||
        const {'UNCLEAR', 'EXECUTION_ERROR'}.contains(liveStatus) ||
        promoteTrustedLive;
    final staleLiveUnclear =
        durableCommitted && !durableBusinessUnclear && liveOutcome == 'UNCLEAR';
    final metadata = durableBusinessUnclear || staleLiveUnclear
        ? <String, String>{
            for (final entry in b.metadata.entries)
              if (!const {
                'agentOutcome',
                'reportCallOutcome',
                'callOutcome',
                'outcome',
                'agent_outcome',
                'agentReason',
                'resultReason',
                'resultCode',
              }.contains(entry.key))
                entry.key: entry.value,
            ...a.metadata,
          }
        : durableCommitted || hasReportedOutcome
        ? <String, String>{...a.metadata}
        : {
            ...a.metadata,
            ...b.metadata,
            if ((a.metadata['agentOutcome'] ?? '').trim().isNotEmpty)
              'agentOutcome': a.metadata['agentOutcome']!,
          };
    if (a.metadata['physicalTerminalOnly'] == 'true' &&
        trustedLiveFinal &&
        (const {
              'SUCCESS',
              'COMPLETED',
              'FAILED',
              'UNCLEAR',
              'NEEDS_RECALL',
              'USER_CANCELLED',
              'USER_CANCELED',
            }.contains(liveOutcome) ||
            const {'UNCLEAR', 'EXECUTION_ERROR'}.contains(liveStatus))) {
      metadata.remove('physicalTerminalOnly');
      metadata.remove('physicalOnlyOutcomePending');
    }
    // A durable result description can occupy transcript via the legacy detail
    // fallback. Retain actual dialogue from this same call when that happens.
    final transcript =
        CallDialogue.parse(a.transcript).isEmpty &&
            CallDialogue.parse(b.transcript).isNotEmpty
        ? b.transcript
        : a.transcript.isEmpty
        ? b.transcript
        : a.transcript;
    final callId = a.callId.isEmpty ? b.callId : a.callId;
    final targetName = a.targetName.isEmpty ? b.targetName : a.targetName;
    final phoneNumber = a.phoneNumber.isEmpty ? b.phoneNumber : a.phoneNumber;
    final enrichDescription =
        !durableCommitted && !hasReportedOutcome && hasLiveOutcome;
    final promoteLiveStatus =
        !durableCommitted &&
        !hasReportedOutcome &&
        (liveStatus == 'EXECUTION_ERROR' ||
            (liveStatus == 'UNCLEAR' && !hasReportedOutcome) ||
            promoteTrustedLive);
    final status = promoteLiveStatus ? liveStatus : a.status;
    final headline = enrichDescription && b.headline.isNotEmpty
        ? b.headline
        : a.headline;
    final detail = enrichDescription && b.detail.isNotEmpty
        ? b.detail
        : a.detail;
    final fields = durableBusinessUnclear || staleLiveUnclear
        ? a.fields
        : durableCommitted || hasReportedOutcome
        ? a.fields.isEmpty && b.fields.isNotEmpty
              ? b.fields
              : a.fields
        : enrichDescription && b.fields.isNotEmpty
        ? b.fields
        : a.fields.isEmpty && b.fields.isNotEmpty
        ? b.fields
        : a.fields;
    final billing = durableCommitted
        ? a.billing ?? b.billing
        : _billing(a.billing, b.billing);
    if (metadata.length == a.metadata.length &&
        metadata.entries.every(
          (entry) => a.metadata[entry.key] == entry.value,
        ) &&
        callId == a.callId &&
        targetName == a.targetName &&
        phoneNumber == a.phoneNumber &&
        status == a.status &&
        headline == a.headline &&
        detail == a.detail &&
        transcript == a.transcript &&
        identical(fields, a.fields) &&
        identical(billing, a.billing)) {
      return fact;
    }
    return ConversationMessage(
      id: fact.id,
      role: fact.role,
      text: fact.text,
      commandId: fact.commandId,
      toolCallId: fact.toolCallId,
      options: fact.options,
      transient: fact.transient,
      receipt: CallReceipt(
        attemptId: a.attemptId,
        callId: callId,
        targetName: targetName,
        phoneNumber: phoneNumber,
        status: status,
        headline: headline,
        detail: detail,
        transcript: transcript,
        fields: fields,
        billing: billing,
        metadata: metadata,
      ),
    );
  }

  static ReceiptBilling? _billing(
    ReceiptBilling? durable,
    ReceiptBilling? live,
  ) {
    if (live == null) return durable;
    if (durable == null) return live;
    if (durable.sessionId != live.sessionId) return durable;
    if (_settled(durable) && !_settled(live)) return durable;
    return live;
  }

  static bool _settled(ReceiptBilling billing) => const {
    'SETTLED',
    'RELEASED',
  }.contains(billing.state.trim().toUpperCase());

  static String _status(ConversationMessage message) =>
      message.receipt?.status ?? message.batchReceipt?.status ?? '';
  static bool _terminal(String status) {
    final value = status.trim().toUpperCase();
    return const {
          'COMPLETED',
          'SUCCESS',
          'DONE',
          'FINISHED',
          'ENDED',
          'FAILED',
          'INCOMPLETE',
          'PARTIAL',
          'PARTIALLY_COMPLETED',
          'NEEDS_FOLLOW_UP',
          'EXECUTION_ERROR',
          'UNCLEAR',
          'CANCELLED',
          'CANCELED',
          'REJECTED',
          'NOT_FOUND',
          'NO_ANSWER',
          'MISSED_CALL',
          'TIMEOUT',
          'USER_CANCELLED',
          'USER_CANCELED',
          'TERMINATED',
        }.contains(value) ||
        const [
          'COMPLETED',
          'FAILED',
          'CANCELLED',
          'CANCELED',
          'REJECTED',
          'NOT_FOUND',
          'NO_ANSWER',
          'MISSED_CALL',
          'TIMEOUT',
          'ENDED',
          'TERMINATED',
        ].any(value.contains);
  }
}
