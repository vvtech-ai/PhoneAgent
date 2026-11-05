import '../../domain/conversation_messages.dart';

/// Only presentation values; never includes execution source parameters.
Iterable<Object?> conversationConfirmationValues(
  ConversationMessage message,
) sync* {
  final single = message.confirmation;
  yield single != null;
  if (single != null) {
    yield single.isBatch;
    final rows = single.rows;
    yield rows.length;
    for (final row in rows) {
      yield row.label;
      yield row.value;
    }
  }
  final batch = message.batchConfirmation;
  yield batch != null;
  if (batch == null) return;
  yield batch.billingAlias; // Owns the contact expansion lifecycle.
  final sections = batch.sections.where((section) => section.rows.isNotEmpty);
  yield sections.length;
  for (final (index, section) in sections.indexed) {
    yield section.title.trim().isNotEmpty
        ? section.title
        : index == 0
        ? '任务信息'
        : '补充信息';
    yield section.rows.length;
    for (final row in section.rows) {
      yield row.label;
      yield row.value;
    }
  }
  yield batch.hasAudit;
  if (batch.hasAudit) {
    yield batch.originalCount;
    yield batch.callableCount;
    yield batch.skippedCount;
    yield batch.issues.length;
    for (final issue in batch.issues) {
      yield [
        issue.label,
        issue.value,
      ].where((value) => value.trim().isNotEmpty).join('：');
    }
    yield batch.recipients.length;
    for (final recipient in batch.recipients) {
      yield recipient.displayName;
      yield recipient.salutation;
      yield recipient.detail.trim().isEmpty ? '' : recipient.detail;
      yield recipient.status.trim().isEmpty ? '' : recipient.status;
    }
  }
  yield batch.rules.length;
  if (batch.rules.isNotEmpty) {
    yield batch.decision.label;
    for (final row in batch.rules) {
      yield row.label;
      yield row.value;
    }
  }
  yield batch.showsAssistantText ? batch.assistantText : '';
}
