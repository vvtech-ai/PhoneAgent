import 'call_receipt.dart';

enum BatchItemOutcome { success, failed, unclear, cancelled, running }

BatchItemOutcome batchItemOutcome(String raw) =>
    switch (raw.trim().toUpperCase()) {
      'SUCCESS' ||
      'ACCEPTED' ||
      'COMPLETED' ||
      'CONFIRMED' ||
      'DONE' ||
      'FINISHED' => BatchItemOutcome.success,
      'FAILED' ||
      'FAIL' ||
      'ERROR' ||
      'DECLINED' ||
      'REJECTED' ||
      'REFUSED' ||
      'MISSED' ||
      'MISSED_CALL' ||
      'NO_ANSWER' ||
      'NOANSWER' ||
      'TIMEOUT' ||
      'HUNG_UP' ||
      'HANG_UP' ||
      'HANGUP' => BatchItemOutcome.failed,
      'USER_CANCELLED' ||
      'USER_CANCELED' ||
      'CANCELLED' ||
      'CANCELED' ||
      'USER_INTERRUPTED' => BatchItemOutcome.cancelled,
      'STARTED' ||
      'REQUESTED' ||
      'CALLING' ||
      'DIALING' ||
      'RINGING' ||
      'CONNECTED' ||
      'ENDING' ||
      'CANCELLING' ||
      'STOP_ACCEPTED' ||
      'PRIMARY_CLOSED_FORK_OBSERVING' ||
      'RECALLING' ||
      'RETRYING' ||
      'REDIALING' ||
      'LINE_BUSY_WAITING' ||
      'WAITING_FOR_LINE' ||
      'WAITING_CALL' ||
      'RUNNING' ||
      'VERIFYING' => BatchItemOutcome.running,
      _ => BatchItemOutcome.unclear,
    };

class BatchReceiptItem {
  BatchReceiptItem.fromJson(Map<String, Object?> data, String fallbackId)
    : id = ReceiptValues.first([
        ReceiptValues.text(data, 'itemId'),
        fallbackId,
      ]),
      targetName = ReceiptValues.text(data, 'targetName'),
      phoneNumber = ReceiptValues.text(data, 'phoneNumber'),
      status = ReceiptValues.text(data, 'status'),
      headline =
          const {
            'LINE_BUSY_WAITING',
            'WAITING_FOR_LINE',
            'WAITING_CALL',
          }.contains(ReceiptValues.text(data, 'status').toUpperCase())
          ? '等待呼叫中'
          : ReceiptValues.text(data, 'headline'),
      detail = ReceiptValues.text(data, 'detail'),
      transcript = ReceiptValues.text(data, 'transcript'),
      callId = ReceiptValues.text(data, 'callId'),
      attemptId = ReceiptValues.text(data, 'callAttemptId'),
      attemptCount =
          int.tryParse(ReceiptValues.text(data, 'attemptCount')) ?? 1,
      recalled = ReceiptValues.text(data, 'recalled') == 'true',
      abnormal = ReceiptValues.text(data, 'abnormal') == 'true',
      fields = CallReceipt.parseFields(data['receiptFields']),
      billing = List.unmodifiable([
        if (data['billingSummaries'] case final List values)
          for (final value in values)
            if (ReceiptBilling.parse(value) case final summary?) summary,
      ]);

  BatchReceiptItem._({
    required this.id,
    required this.targetName,
    required this.phoneNumber,
    required this.status,
    required this.headline,
    required this.detail,
    required this.transcript,
    required this.callId,
    required this.attemptId,
    required this.attemptCount,
    required this.recalled,
    required this.abnormal,
    required this.fields,
    required this.billing,
  });

  BatchReceiptItem withBillingFallback(ReceiptBilling? fallback) {
    if (billing.isNotEmpty || fallback == null || attemptId.isEmpty) {
      return this;
    }
    return BatchReceiptItem._(
      id: id,
      targetName: targetName,
      phoneNumber: phoneNumber,
      status: status,
      headline: headline,
      detail: detail,
      transcript: transcript,
      callId: callId,
      attemptId: attemptId,
      attemptCount: attemptCount,
      recalled: recalled,
      abnormal: abnormal,
      fields: fields,
      billing: List.unmodifiable([fallback]),
    );
  }

  final String id,
      targetName,
      phoneNumber,
      status,
      headline,
      detail,
      transcript,
      callId,
      attemptId;
  final int attemptCount;
  final bool recalled, abnormal;
  final List<ReceiptField> fields;
  final List<ReceiptBilling> billing;
  BatchItemOutcome get outcome => batchItemOutcome(status);
  String? get recordingCallId {
    final anchor = callId.trim();
    if (anchor.isEmpty) return null;
    if (billing.isNotEmpty &&
        (billing.last.connectedDurationMillis ?? 0) <= 0) {
      return null;
    }
    return anchor;
  }
}

class BatchReceipt {
  BatchReceipt.fromJson(
    Map<String, Object?> data, {
    required String fallbackId,
    this.resultSequence = 0,
  }) : id = ReceiptValues.first([
         ReceiptValues.text(data, 'batchId'),
         fallbackId,
       ]),
       explicitId = ReceiptValues.text(data, 'batchId'),
       status = ReceiptValues.text(data, 'status'),
       executionStatus = ReceiptValues.text(data, 'executionStatus'),
       headline = ReceiptValues.text(data, 'headline'),
       detail = ReceiptValues.text(data, 'detail'),
       resultCode = ReceiptValues.text(data, 'resultCode'),
       sourceSnapshotId = ReceiptValues.text(data, 'sourceSnapshotId'),
       sourceSnapshotVersion = int.tryParse(
         ReceiptValues.text(data, 'sourceSnapshotVersion'),
       ),
       totalHint = int.tryParse(ReceiptValues.text(data, 'totalCount')) ?? 0,
       items = List.unmodifiable([
         if (data['items'] case final List values)
           for (final (index, value) in values.indexed)
             if (value is Map<String, Object?>)
               BatchReceiptItem.fromJson(value, '$fallbackId:$index'),
       ]);

  BatchReceipt._withItems(BatchReceipt source, List<BatchReceiptItem> items)
    : id = source.id,
      explicitId = source.explicitId,
      status = source.status,
      executionStatus = source.executionStatus,
      headline = source.headline,
      detail = source.detail,
      resultCode = source.resultCode,
      resultSequence = source.resultSequence,
      sourceSnapshotId = source.sourceSnapshotId,
      sourceSnapshotVersion = source.sourceSnapshotVersion,
      totalHint = source.totalHint,
      items = List.unmodifiable(items);

  BatchReceipt withBillingFallback(
    Map<String, ReceiptBilling> billingByAttempt,
  ) => BatchReceipt._withItems(
    this,
    items
        .map(
          (item) => item.withBillingFallback(billingByAttempt[item.attemptId]),
        )
        .toList(growable: false),
  );

  final String id,
      explicitId,
      status,
      headline,
      detail,
      resultCode,
      sourceSnapshotId;
  final String executionStatus;
  final int resultSequence;
  final int? sourceSnapshotVersion;
  final int totalHint;
  final List<BatchReceiptItem> items;
  int get totalCount => totalHint > items.length ? totalHint : items.length;
  int get completedCount =>
      items.where((i) => i.outcome != BatchItemOutcome.running).length;
  int get successCount =>
      items.where((i) => i.outcome == BatchItemOutcome.success).length;
  bool get isExecutionError =>
      executionStatus.trim().toUpperCase() == 'EXECUTION_ERROR';
  bool get businessResultUnavailable =>
      resultCode == 'BUSINESS_RESULT_UNAVAILABLE';
  bool get isRunning =>
      !isExecutionError &&
      (items.any((i) => i.outcome == BatchItemOutcome.running) ||
          batchItemOutcome(status) == BatchItemOutcome.running);

  /// An execution error is visible to the user but does not prove that an
  /// accepted stop has physically and financially settled.
  bool get stopSettled => !isExecutionError && !isRunning;
  bool get pointsRejected =>
      items.isNotEmpty &&
      items.every((i) => i.attemptCount == 0) &&
      (resultCode == 'POINTS_INSUFFICIENT_BALANCE' ||
          headline.contains('积分不足') ||
          items.any(
            (i) => i.headline.contains('积分不足') || i.detail.contains('积分不足'),
          ));
}
