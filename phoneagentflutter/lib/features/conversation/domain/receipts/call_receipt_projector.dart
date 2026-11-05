import '../history/ledger_event.dart';
import 'call_receipt.dart';

class ProjectedCallReceipt {
  const ProjectedCallReceipt(this.anchor, this.receipt);
  final LedgerEvent anchor;
  final CallReceipt receipt;
}

/// Mirrors v71 CallAttemptTimelineProjector. Does not merge retries by task ID.
abstract final class CallReceiptProjector {
  static const terminalTypes = {
    'CALL_COMPLETED',
    'CALL_FAILED',
    'CALL_CANCELLED',
    'CALL_REJECTED',
  };
  static const callTypes = {
    ...terminalTypes,
    'CALL_REQUESTED',
    'CALL_STARTED',
    'CALL_OUTCOME_REPORTED',
  };

  static List<ProjectedCallReceipt> project(Iterable<LedgerEvent> facts) {
    final groups = <(String, String), List<LedgerEvent>>{};
    final unowned = <LedgerEvent>[];
    final unidentifiedResults = <LedgerEvent>[];
    for (final e in facts.where((e) => e.schemaVersion == 1)) {
      final callResult = ReceiptValues.object(e.payload['callResult']);
      final attempt = ReceiptValues.first([
        e.callAttemptId?.trim() ?? '',
        ReceiptValues.text(callResult, 'callAttemptId'),
        ReceiptValues.text(
          ReceiptValues.object(callResult['metadata']),
          'callAttemptId',
        ),
      ]);
      if (attempt.isNotEmpty) {
        groups.putIfAbsent((e.sessionId, attempt), () => []).add(e);
      } else if (terminalTypes.contains(e.type)) {
        unowned.add(e);
      } else if (_isCommittedTerminalResult(e)) {
        unidentifiedResults.add(e);
      }
    }
    final result = <ProjectedCallReceipt>[];
    for (final group in groups.entries) {
      final entries = group.value;
      entries.sort((a, b) => a.sequence.compareTo(b.sequence));
      final projected = _attempt(entries, group.key.$2);
      if (projected != null) result.add(projected);
    }
    for (final e in unowned) {
      result.add(
        ProjectedCallReceipt(
          e,
          CallReceipt(
            attemptId: e.eventId,
            callId: e.callId ?? '',
            targetName: ReceiptValues.text(e.payload, 'recipientRef'),
            status: ReceiptValues.first([
              ReceiptValues.text(e.payload, 'resultCode'),
              e.type,
            ]),
            headline: ReceiptValues.first([
              ReceiptValues.text(e.payload, 'summary'),
              e.type,
            ]),
            detail: ReceiptValues.text(e.payload, 'reason'),
            metadata: {
              'resultCode': ReceiptValues.text(e.payload, 'resultCode'),
            },
            billing: _billing([e]),
          ),
        ),
      );
    }
    for (final e in unidentifiedResults) {
      final source = CallReceipt.fromResult(
        ReceiptValues.object(e.payload['callResult']),
      );
      result.add(
        ProjectedCallReceipt(
          e,
          CallReceipt(
            attemptId: 'unidentified:${e.eventId}',
            callId: source.callId,
            targetName: source.targetName,
            phoneNumber: source.phoneNumber,
            status: source.status,
            headline: source.headline,
            detail: source.detail,
            transcript: source.transcript,
            fields: source.fields,
            billing: source.billing,
            metadata: {
              ...source.metadata,
              'committedCallResult': 'true',
              'committedCallResultCommandId': e.commandId!,
              if ((source.metadata['agentOutcome'] ?? '').trim().isNotEmpty)
                CallReceipt.ledgerOutcomeSourceKey: 'committed',
            },
          ),
        ),
      );
    }
    result.sort((a, b) => a.anchor.sequence.compareTo(b.anchor.sequence));
    return List.unmodifiable(result);
  }

  static bool _isCommittedTerminalResult(LedgerEvent e) {
    if (e.type != 'ASSISTANT_TURN_COMMITTED' ||
        (e.commandId?.trim() ?? '').isEmpty) {
      return false;
    }
    final result = ReceiptValues.object(e.payload['callResult']);
    final receipt = CallReceipt.fromResult(result);
    return result.isNotEmpty &&
        receipt.status.trim().isNotEmpty &&
        !receipt.isRunning;
  }

  static ProjectedCallReceipt? _attempt(
    List<LedgerEvent> events,
    String attemptId,
  ) {
    final calls = events.where((e) => callTypes.contains(e.type)).toList();
    final committedResult = events.where(_isCommittedTerminalResult).lastOrNull;
    final execution = events
        .where(
          (e) =>
              e.type == 'ASSISTANT_TURN_COMMITTED' &&
              ReceiptValues.text(
                    ReceiptValues.object(e.payload['callResult']),
                    'status',
                  ).toUpperCase() ==
                  'EXECUTION_ERROR',
        )
        .lastOrNull;
    if (calls.isEmpty && committedResult == null) return null;
    if (calls.isEmpty && execution == null) {
      final source = CallReceipt.fromResult(
        ReceiptValues.object(committedResult!.payload['callResult']),
      );
      return ProjectedCallReceipt(
        committedResult,
        CallReceipt(
          attemptId: attemptId,
          callId: source.callId,
          targetName: source.targetName,
          phoneNumber: source.phoneNumber,
          status: source.status,
          headline: source.headline,
          detail: source.detail,
          transcript: source.transcript,
          fields: source.fields,
          billing: source.billing,
          metadata: {
            ...source.metadata,
            'committedCallResult': 'true',
            'committedCallResultCommandId': committedResult.commandId!,
            if ((source.metadata['agentOutcome'] ?? '').trim().isNotEmpty)
              CallReceipt.ledgerOutcomeSourceKey: 'committed',
          },
        ),
      );
    }
    final requested = calls
        .where((e) => e.type == 'CALL_REQUESTED')
        .firstOrNull;
    final started = calls.where((e) => e.type == 'CALL_STARTED').lastOrNull;
    final terminal = calls
        .where((e) => terminalTypes.contains(e.type))
        .lastOrNull;
    final reported = calls
        .where((e) => e.type == 'CALL_OUTCOME_REPORTED')
        .lastOrNull;
    final terminalResult =
        execution ??
        (committedResult != null &&
                (reported == null ||
                    committedResult.sequence > reported.sequence)
            ? committedResult
            : null);
    final terminalPayload = ReceiptValues.object(
      terminalResult?.payload['callResult'],
    );
    final terminalMetadata = ReceiptValues.object(terminalPayload['metadata']);
    final toolRequest = events
        .where((e) => e.type == 'TOOL_REQUESTED')
        .lastOrNull;
    final toolResult = events
        .where((e) => e.type == 'TOOL_RESULT_RECORDED')
        .lastOrNull;
    final result = ReceiptValues.object(toolResult?.payload['result']);
    final metadata = ReceiptValues.object(result['metadata']);
    final resultFields = CallReceipt.parseFields(
      terminalPayload['receiptFields'],
    );
    final receipt = ReceiptValues.object(
      reported?.payload['callReceipt'] is Map
          ? reported!.payload['callReceipt']
          : terminal?.payload['callReceipt'] is Map
          ? terminal!.payload['callReceipt']
          : started?.payload['callReceipt'],
    );
    String t(Map<String, Object?>? data, String key) =>
        ReceiptValues.text(data ?? const {}, key);
    String first(List<String> values) => ReceiptValues.first(values);
    final physicalOnlyOutcomePending =
        terminal?.type == 'CALL_COMPLETED' &&
        reported == null &&
        terminalResult == null;
    final trustedUnclear =
        execution == null &&
        (reported != null
            ? t(reported.payload, 'outcome').toUpperCase() == 'UNCLEAR'
            : t(terminalMetadata, 'agentOutcome').toUpperCase() == 'UNCLEAR');
    final callId = first([
      t(terminalPayload, 'callId'),
      t(terminalMetadata, 'callId'),
      t(receipt, 'callId'),
      terminal?.callId ?? '',
      started?.callId ?? '',
      reported?.callId ?? '',
      requested?.callId ?? '',
      t(metadata, 'callId'),
    ]);
    final status = execution != null
        ? 'EXECUTION_ERROR'
        : reported != null
        ? ReceiptValues.outcome(t(reported.payload, 'outcome'))
        : terminalResult != null
        ? t(terminalPayload, 'status')
        : terminal != null
        ? first([t(receipt, 'callState'), terminal.type])
        : started != null
        ? 'CALL_STARTED'
        : 'CALL_REQUESTED';
    final anchor =
        requested ?? started ?? terminal ?? reported ?? terminalResult!;
    return ProjectedCallReceipt(
      anchor,
      CallReceipt(
        attemptId: attemptId,
        callId: callId,
        targetName: first([
          t(terminalPayload, 'targetName'),
          t(terminalMetadata, 'targetName'),
          t(receipt, 'targetName'),
          t(
            ReceiptValues.object(toolRequest?.payload['arguments']),
            'targetName',
          ),
          t(requested?.payload, 'recipientRef'),
        ]),
        phoneNumber: first([
          t(terminalPayload, 'phoneNumber'),
          t(terminalMetadata, 'phoneNumber'),
          t(receipt, 'dialNumber'),
          t(receipt, 'phoneNumber'),
        ]),
        status: status,
        headline: first([
          t(terminalPayload, 'headline'),
          t(reported?.payload, 'headline'),
          t(terminal?.payload, 'summary'),
          t(result, 'headline'),
          status,
        ]),
        detail: first([
          t(terminalPayload, 'detail'),
          t(receipt, 'resultReason'),
          t(receipt, 'statusMessage'),
          t(reported?.payload, 'reason'),
          t(terminal?.payload, 'reason'),
          t(result, 'detail'),
        ]),
        transcript: first([
          t(terminalMetadata, 'dialogueTranscript'),
          t(terminalMetadata, 'dialogueDetail'),
          t(terminalPayload, 'transcript'),
          t(receipt, 'dialogueDetail'),
          t(metadata, 'dialogueTranscript'),
          t(result, 'transcript'),
          t(terminal?.payload, 'transcript'),
        ]),
        fields: resultFields.isNotEmpty
            ? resultFields
            : _fields(
                reported?.payload['receiptFields'],
                result['receiptFields'],
              ),
        billing: trustedUnclear
            ? _billingForUnclear(
                ReceiptBilling.parse(terminalPayload['billingSummary']),
                _billing(events),
              )
            : _preferSettledBilling(
                ReceiptBilling.parse(terminalPayload['billingSummary']),
                _billing(events),
              ),
        metadata: {
          for (final key in metadata.keys)
            if (key != 'physicalTerminalOnly' &&
                key != 'liveFinalResult' &&
                key != 'physicalOnlyOutcomePending' &&
                key != CallReceipt.ledgerOutcomeSourceKey &&
                t(metadata, key).isNotEmpty &&
                (!physicalOnlyOutcomePending ||
                    !const {
                      'agentOutcome',
                      'reportCallOutcome',
                      'callOutcome',
                      'outcome',
                      'agent_outcome',
                    }.contains(key)))
              key: t(metadata, key),
          if (t(receipt, 'phoneNumber').isNotEmpty)
            'phoneNumber': t(receipt, 'phoneNumber'),
          if (t(receipt, 'resultCode').isNotEmpty)
            'resultCode': t(receipt, 'resultCode'),
          if (reported != null) 'agentReason': t(reported.payload, 'reason'),
          for (final key in terminalMetadata.keys)
            if (key != 'physicalTerminalOnly' &&
                key != 'liveFinalResult' &&
                key != 'physicalOnlyOutcomePending' &&
                key != CallReceipt.ledgerOutcomeSourceKey &&
                t(terminalMetadata, key).isNotEmpty)
              key: t(terminalMetadata, key),
          if (reported != null)
            'agentOutcome': t(reported.payload, 'outcome').toUpperCase(),
          if (t(terminalPayload, 'resultCode').isNotEmpty)
            'resultCode': t(terminalPayload, 'resultCode'),
          if (callId.isNotEmpty) 'callId': callId,
          if (reported != null && t(reported.payload, 'outcome').isNotEmpty)
            CallReceipt.ledgerOutcomeSourceKey: 'reported'
          else if (terminalResult != null &&
              t(terminalMetadata, 'agentOutcome').isNotEmpty)
            CallReceipt.ledgerOutcomeSourceKey: 'committed',
          if (committedResult != null) ...{
            'committedCallResult': 'true',
            'committedCallResultCommandId': committedResult.commandId!,
          },
          if (terminal?.type == 'CALL_COMPLETED' &&
              reported == null &&
              terminalResult == null)
            'physicalTerminalOnly': 'true',
        },
      ),
    );
  }

  static List<ReceiptField> _fields(Object? reported, Object? result) {
    final fields = CallReceipt.parseFields(reported);
    return fields.isNotEmpty ? fields : CallReceipt.parseFields(result);
  }

  static ReceiptBilling? _billing(List<LedgerEvent> events) {
    ReceiptBilling? latest;
    ReceiptBilling? physicalSettlement;
    for (final event in events.reversed) {
      if (!callTypes.contains(event.type) &&
          event.type != 'TOOL_RESULT_RECORDED') {
        continue;
      }
      final receipt = ReceiptValues.object(event.payload['callReceipt']);
      final result = ReceiptValues.object(event.payload['result']);
      for (final value in [
        receipt['billingSummary'],
        result['billingSummary'],
        event.payload['billingSummary'],
      ]) {
        final billing = ReceiptBilling.parse(value);
        latest = _preferSettledBilling(latest, billing);
        if (event.type == 'CALL_COMPLETED' &&
            billing != null &&
            _settled(billing)) {
          physicalSettlement ??= billing;
        }
      }
    }
    if (physicalSettlement != null && latest != null && !_settled(latest)) {
      return physicalSettlement;
    }
    return latest;
  }

  static bool _settled(ReceiptBilling billing) => const {
    'SETTLED',
    'RELEASED',
  }.contains(billing.state.trim().toUpperCase());

  static ReceiptBilling? _billingForUnclear(
    ReceiptBilling? terminal,
    ReceiptBilling? fact,
  ) {
    if (fact == null) return terminal;
    if (terminal == null) return fact;
    if (terminal.sessionId != fact.sessionId) {
      return !_settled(terminal) && _settled(fact) ? fact : terminal;
    }
    return _preferSettledBilling(terminal, fact);
  }

  static ReceiptBilling? _preferSettledBilling(
    ReceiptBilling? latest,
    ReceiptBilling? earlier,
  ) {
    if (latest == null) return earlier;
    if (earlier == null || latest.sessionId != earlier.sessionId) return latest;
    return _settled(earlier) && !_settled(latest) ? earlier : latest;
  }
}
