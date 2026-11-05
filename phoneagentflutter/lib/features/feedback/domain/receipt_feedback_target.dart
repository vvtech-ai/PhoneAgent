import 'dart:convert';
import '../../conversation/domain/conversation_messages.dart';
import 'call_evaluation.dart';

/// Only server call/batch IDs are anchors, never session IDs or local fallbacks.
FeedbackTarget? receiptFeedbackTarget(ConversationMessage message) {
  final batch = message.batchReceipt;
  if (batch != null) {
    final id = batch.explicitId.trim();
    if (id.isEmpty || batch.status.trim().toUpperCase() == 'RUNNING') {
      return null;
    }
    return FeedbackTarget(FeedbackTargetKind.batch, id);
  }
  final id = message.receipt?.callId.trim() ?? '';
  return id.isEmpty ? null : FeedbackTarget(FeedbackTargetKind.call, id);
}

/// Value-based revision: reprojecting unchanged receipts is not a refresh event.
/// This remains local and is never sent to the server or written to logs.
String receiptFeedbackRevision(ConversationMessage message) {
  final call = message.receipt;
  final batch = message.batchReceipt;
  final metadata = call?.metadata.entries.toList()
    ?..sort((a, b) => a.key.compareTo(b.key));
  return jsonEncode([
    if (call != null) ...[
      call.attemptId,
      call.callId,
      call.status,
      call.headline,
      call.detail,
      call.transcript,
      for (final entry in metadata!) [entry.key, entry.value],
      for (final field in call.fields) [field.key, field.label, field.value],
      call.billing?.state,
      call.billing?.connectedDurationMillis,
      call.billing?.chargedPoints,
    ],
    if (batch != null) ...[
      batch.explicitId,
      batch.status,
      batch.executionStatus,
      batch.headline,
      batch.resultCode,
      batch.sourceSnapshotId,
      batch.sourceSnapshotVersion,
      batch.totalHint,
      for (final item in batch.items)
        [
          item.id,
          item.callId,
          item.attemptId,
          item.status,
          item.headline,
          item.detail,
          item.transcript,
          item.attemptCount,
          item.recalled,
          item.abnormal,
          for (final field in item.fields) [field.key, field.label, field.value],
          for (final billing in item.billing)
            [
              billing.state,
              billing.connectedDurationMillis,
              billing.chargedPoints,
            ],
        ],
    ],
  ]);
}
