import '../../domain/conversation_messages.dart';
import '../../domain/receipts/batch_receipt.dart';
import '../../domain/receipts/call_dialogue.dart';
import 'call_receipt_text.dart';
import 'conversation_single_receipt_values.dart';

/// Immutable presentation values, excluding execution and raw payload fields.
Iterable<Object?> conversationReceiptValues(ConversationMessage message) sync* {
  yield* conversationSingleReceiptValues(message.receipt);
  final receipt = message.batchReceipt;
  yield receipt != null;
  if (receipt != null) {
    yield receipt.pointsRejected;
    yield receipt.pointsRejected || !receipt.isRunning ? receipt.headline : '';
    if (!receipt.pointsRejected) {
      yield receipt.totalCount;
      yield receipt.completedCount;
      yield receipt.totalCount == 0 ? receipt.status : '';
      yield receipt.isRunning;
      yield receipt.successCount;
      yield receipt.items.length;
      for (final item in receipt.items) {
        yield item.id; // Owns the local transcript expansion lifecycle.
        yield [
          item.targetName,
          item.phoneNumber,
          '未命名联系人',
        ].map((value) => value.trim()).firstWhere((value) => value.isNotEmpty);
        yield [item.headline, item.detail, item.status]
            .map((value) => value.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        yield item.outcome;
        final business = item.fields
            .where((field) => field.key == 'businessResult')
            .firstOrNull;
        yield item.outcome == BatchItemOutcome.running
            ? ''
            : business?.value.trim() ?? '';
        yield item.recordingCallId;
        final lines = CallDialogue.parse(item.transcript);
        yield lines.length;
        for (final line in lines) {
          yield line.role;
          yield line.text;
        }
        final sections = [
          for (final (index, billing) in item.billing.indexed)
            if (CallReceiptText.billingRows(billing) case final rows
                when rows.isNotEmpty)
              (item.billing.length > 1 ? '第 ${index + 1} 次结算' : '积分结算', rows),
        ];
        yield sections.length;
        for (final (title, rows) in sections) {
          yield title;
          yield rows.length;
          yield* rows;
        }
      }
    }
  }
  final document = message.document;
  yield document != null;
  if (document != null) {
    yield document.files.length;
    for (final file in document.files) {
      yield file.name;
      yield file.metadata;
    }
  }
}
