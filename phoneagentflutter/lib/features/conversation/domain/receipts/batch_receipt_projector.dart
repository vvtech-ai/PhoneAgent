import '../history/ledger_event.dart';
import 'batch_receipt.dart';
import 'call_receipt.dart';
import 'call_receipt_projector.dart';

class ProjectedBatchReceipt {
  const ProjectedBatchReceipt(this.anchor, this.receipt);
  final LedgerEvent anchor;
  final BatchReceipt receipt;
}

abstract final class BatchReceiptProjector {
  static Map<String, Object?> payload(Map<String, Object?> data) =>
      data['batchCallResult'] is Map<String, Object?>
      ? ReceiptValues.object(data['batchCallResult'])
      : ReceiptValues.object(
          ReceiptValues.object(data['result'])['batchCallResult'],
        );

  static List<ProjectedBatchReceipt> project(Iterable<LedgerEvent> events) {
    final grouped = <(String, String), ProjectedBatchReceipt>{};
    final ordered = events.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    const originalTypes = {'ASSISTANT_TURN_COMMITTED', 'TOOL_RESULT_RECORDED'};
    final originalBySequence = {
      for (final event in ordered)
        if (event.schemaVersion == 1 && originalTypes.contains(event.type))
          (event.sessionId, event.sequence): event,
    };
    final billingBySessionAndAttempt = {
      for (final projected in CallReceiptProjector.project(ordered))
        if (projected.receipt.billing case final billing?)
          (projected.anchor.sessionId, projected.receipt.attemptId): billing,
    };
    for (final e in ordered) {
      if (e.schemaVersion != 1) continue;
      final reconciled = e.type == 'BATCH_RESULT_RECONCILED';
      if (!reconciled && !originalTypes.contains(e.type)) {
        continue;
      }
      final data = payload(e.payload);
      if (data.isEmpty) continue;
      if (reconciled) {
        final sourceSequence = e.payload['sourceResultSequence'];
        final batchId = ReceiptValues.text(e.payload, 'batchId');
        if (sourceSequence is! int ||
            sourceSequence <= 0 ||
            sourceSequence >= e.sequence ||
            batchId.isEmpty ||
            ReceiptValues.text(e.payload, 'resolutionCode') !=
                'BUSINESS_RESULT_UNAVAILABLE' ||
            ReceiptValues.text(data, 'batchId') != batchId ||
            ReceiptValues.text(data, 'resultCode') !=
                'BUSINESS_RESULT_UNAVAILABLE' ||
            ReceiptValues.text(data, 'status') != 'INCOMPLETE' ||
            ReceiptValues.text(data, 'executionStatus') != 'FINISHED') {
          continue;
        }
        final source = originalBySequence[(e.sessionId, sourceSequence)];
        final sourceResult = source == null
            ? const <String, Object?>{}
            : payload(source.payload);
        if (ReceiptValues.text(sourceResult, 'batchId') != batchId ||
            ReceiptValues.text(sourceResult, 'executionStatus') !=
                'EXECUTION_ERROR' ||
            !grouped.containsKey((e.sessionId, batchId))) {
          continue;
        }
      }
      final parsed = BatchReceipt.fromJson(
        {
          ...data,
          if (ReceiptValues.text(data, 'detail').isEmpty &&
              ReceiptValues.text(data, 'executionStatus') == 'EXECUTION_ERROR')
            'detail': ReceiptValues.text(e.payload, 'text'),
        },
        fallbackId:
            (e.commandId?.isNotEmpty ?? false) &&
                ReceiptValues.text(data, 'batchId').isEmpty
            ? 'command:${e.commandId}'
            : e.eventId,
        resultSequence: e.sequence,
      );
      final billingByAttempt = {
        for (final item in parsed.items)
          if (billingBySessionAndAttempt[(e.sessionId, item.attemptId)]
              case final billing?)
            item.attemptId: billing,
      };
      final receipt = parsed.withBillingFallback(billingByAttempt);
      if ((receipt.items.isEmpty && !receipt.isExecutionError) ||
          receipt.pointsRejected) {
        continue;
      }
      final key = (e.sessionId, receipt.id);
      grouped[key] = ProjectedBatchReceipt(grouped[key]?.anchor ?? e, receipt);
    }
    return List.unmodifiable(grouped.values);
  }

  static String? pointsNotice(LedgerEvent e) {
    if (e.schemaVersion != 1 || e.type != 'ASSISTANT_TURN_COMMITTED') {
      return null;
    }
    final data = payload(e.payload);
    if (data.isEmpty) return null;
    final receipt = BatchReceipt.fromJson(data, fallbackId: e.eventId);
    final text = ReceiptValues.text(e.payload, 'text');
    if (!receipt.pointsRejected || receipt.items.length < 2 || text.isEmpty) {
      return null;
    }
    return text.startsWith('多路积分不足') ? text : '多路积分不足，$text';
  }
}
