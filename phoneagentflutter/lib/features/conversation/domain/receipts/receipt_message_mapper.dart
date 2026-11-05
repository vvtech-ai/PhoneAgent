import '../conversation_messages.dart';
import 'call_receipt.dart';
import 'batch_receipt.dart';
import 'batch_receipt_projector.dart';

/// Produces typed, side-effect-free live overlays; durable facts later replace
/// only matching identities. A command fallback never links unrelated history.
abstract final class ReceiptMessageMapper {
  static List<ConversationMessage> fromFinal(
    Map<String, Object?> data,
    String command,
  ) {
    final messages = <ConversationMessage>[];
    final single = ReceiptValues.object(data['callResult']);
    final receipt = CallReceipt.fromResult(single, liveFinalResult: true);
    if (single.isNotEmpty && !receipt.isRunning) {
      final identity = ReceiptValues.first([
        receipt.attemptId,
        receipt.callId,
        command,
      ]);
      messages.add(
        ConversationMessage(
          id: 'local:$command:receipt:$identity',
          role: MessageRole.assistant,
          text: '',
          commandId: command,
          receipt: receipt,
          transient: true,
        ),
      );
    }
    final batchData = BatchReceiptProjector.payload(data);
    if (batchData.isNotEmpty) {
      final receipt = BatchReceipt.fromJson(
        {
          ...batchData,
          if (ReceiptValues.text(batchData, 'detail').isEmpty &&
              ReceiptValues.text(batchData, 'executionStatus') ==
                  'EXECUTION_ERROR')
            'detail': ReceiptValues.text(data, 'text'),
        },
        fallbackId: 'local:$command',
        resultSequence: data['resultSequence'] is int
            ? data['resultSequence'] as int
            : 0,
      );
      if (!receipt.pointsRejected &&
          (receipt.items.isNotEmpty ||
              receipt.totalCount > 0 ||
              receipt.isExecutionError)) {
        messages.add(
          ConversationMessage(
            id: 'local:$command:batch:${receipt.id}',
            role: MessageRole.assistant,
            text: '',
            commandId: command,
            batchReceipt: receipt,
            transient: true,
          ),
        );
      }
    }
    return List.unmodifiable(messages);
  }
}
