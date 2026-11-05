import 'package:flutter/material.dart';
import '../../../../../core/design/receipt_tokens.dart';
import '../../../domain/receipts/batch_receipt.dart';
import '../../../domain/receipts/call_dialogue.dart';
import 'receipt_sections.dart';
import 'native_batch_receipt_shell.dart';
import 'native_batch_item_header.dart';
import 'native_batch_transcript.dart';

class BatchReceiptCard extends StatelessWidget {
  const BatchReceiptCard({
    super.key,
    required this.receipt,
    this.recordingBuilder,
  });
  final BatchReceipt receipt;
  final Widget Function(String callId, bool compact)? recordingBuilder;
  @override
  Widget build(BuildContext context) {
    if (receipt.pointsRejected) {
      return Text(receipt.headline, style: ReceiptTokens.body);
    }
    if (receipt.items.isEmpty && receipt.isExecutionError) {
      final explanation = receipt.detail.isNotEmpty
          ? receipt.detail
          : receipt.headline.isNotEmpty && receipt.headline != '执行异常'
          ? receipt.headline
          : '本次任务已结束，结果处理异常';
      return NativeBatchReceiptShell(
        title: '执行结果',
        status: '执行异常',
        child: Text(explanation, style: ReceiptTokens.body),
      );
    }
    final waitingForFinal = receipt.status.trim().toUpperCase() == 'VERIFYING';
    final businessUnavailable = receipt.businessResultUnavailable;
    final progress = receipt.totalCount == 0
        ? 0.0
        : (receipt.completedCount / receipt.totalCount).clamp(0.0, 1.0);
    final items = [
      for (final item in receipt.items)
        BatchReceiptItemCard(
          key: ValueKey('${receipt.id}:${item.id}'),
          item: item,
          terminalExecutionError: receipt.isExecutionError,
          recordingBuilder: recordingBuilder,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NativeBatchReceiptShell(
          title: '批量外呼进度',
          status: receipt.totalCount > 0
              ? '${receipt.completedCount}/${receipt.totalCount}'
              : receipt.status,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (waitingForFinal ||
                  receipt.items.any((item) => item.status == 'VERIFYING'))
                Text(receipt.headline, style: ReceiptTokens.caption),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: progress, end: progress),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(99),
                  color: const Color(0xFF0A84FF),
                  backgroundColor: const Color(0xFFE9EDF2),
                  semanticsLabel: businessUnavailable
                      ? '执行记录数量，业务结果无法确认'
                      : '已产生结果，不代表成功率',
                  semanticsValue:
                      '${receipt.completedCount}/${receipt.totalCount}',
                ),
              ),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      businessUnavailable
                          ? '业务结果无法确认'
                          : waitingForFinal
                          ? '结果尚未确认'
                          : receipt.isRunning
                          ? '结果陆续返回'
                          : '首轮完成',
                      style: ReceiptTokens.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      businessUnavailable
                          ? '${receipt.completedCount}/${receipt.totalCount} 路执行记录'
                          : '${receipt.completedCount}/${receipt.totalCount} 已产生结果',
                      textAlign: TextAlign.right,
                      style: ReceiptTokens.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (receipt.isRunning) ...items,
            ],
          ),
        ),
        if (!receipt.isRunning)
          NativeBatchReceiptShell(
            title: '执行结果',
            status: businessUnavailable
                ? '业务结果无法确认'
                : receipt.executionStatus == 'EXECUTION_ERROR'
                ? '执行异常'
                : '结果回传',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ReceiptTokens.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.headline.isEmpty
                            ? '本轮批量任务已结束'
                            : receipt.headline,
                        style: ReceiptTokens.body.copyWith(
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (receipt.detail.isNotEmpty &&
                          receipt.detail != receipt.headline) ...[
                        const SizedBox(height: 4),
                        Text(receipt.detail, style: ReceiptTokens.caption),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        businessUnavailable
                            ? '${receipt.items.length} 路执行记录'
                            : '${receipt.items.length} 路结果 · ${receipt.successCount} 路完成 · ${receipt.items.length - receipt.successCount} 路需关注',
                        style: ReceiptTokens.caption,
                      ),
                    ],
                  ),
                ),
                ...items,
              ],
            ),
          ),
      ],
    );
  }
}

class BatchReceiptItemCard extends StatefulWidget {
  const BatchReceiptItemCard({
    super.key,
    required this.item,
    this.terminalExecutionError = false,
    this.recordingBuilder,
  });
  final BatchReceiptItem item;
  final bool terminalExecutionError;
  final Widget Function(String callId, bool compact)? recordingBuilder;
  @override
  State<BatchReceiptItemCard> createState() => _BatchReceiptItemCardState();
}

class _BatchReceiptItemCardState extends State<BatchReceiptItemCard> {
  bool _expanded = false;
  @override
  void didUpdateWidget(covariant BatchReceiptItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.item, next = widget.item;
    if (old.id != next.id ||
        old.status != next.status ||
        old.transcript != next.transcript) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unresolvedAfterExecution =
        widget.terminalExecutionError &&
        item.outcome == BatchItemOutcome.running;
    final displayOutcome = unresolvedAfterExecution
        ? BatchItemOutcome.unclear
        : item.outcome;
    final lines = CallDialogue.parse(item.transcript);
    final (tint, background, fallback) = switch (displayOutcome) {
      BatchItemOutcome.success => (
        const Color(0xFF16713A),
        const Color(0xFFEFFAF3),
        '已完成',
      ),
      BatchItemOutcome.running => (
        const Color(0xFF0B68B7),
        const Color(0xFFF2F7FF),
        '进行中',
      ),
      BatchItemOutcome.failed => (
        const Color(0xFFA52218),
        const Color(0xFFFFF5F4),
        '未完成',
      ),
      BatchItemOutcome.unclear => (
        const Color(0xFF8A4F00),
        const Color(0xFFFFF8E8),
        unresolvedAfterExecution ? '待核对' : '待确认',
      ),
      BatchItemOutcome.cancelled => (
        ReceiptTokens.secondary,
        ReceiptTokens.muted,
        '已取消',
      ),
    };
    final business = item.fields
        .where((field) => field.key == 'businessResult')
        .firstOrNull;
    final label = displayOutcome != BatchItemOutcome.running && business != null
        ? business.value.trim()
        : '';
    final resultLabel = item.status == 'VERIFYING'
        ? '状态待核'
        : label.isEmpty
        ? fallback
        : label;
    final name = [
      item.targetName,
      item.phoneNumber,
      '未命名联系人',
    ].map((value) => value.trim()).firstWhere((value) => value.isNotEmpty);
    final summary = unresolvedAfterExecution
        ? '本路结果待核对'
        : [item.headline, item.detail, item.status]
              .map((value) => value.trim())
              .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ReceiptTokens.itemRadius),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ReceiptTokens.itemRadius),
        border: Border.all(color: tint.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NativeBatchItemHeader(
            name: name,
            summary: summary,
            label: resultLabel,
            tint: tint,
          ),
          for (final (index, billing) in item.billing.indexed)
            ReceiptBillingSection(
              billing: billing,
              title: item.billing.length > 1 ? '第 ${index + 1} 次结算' : '积分结算',
            ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: NativeBatchTranscript(lines: lines),
            ),
          if (lines.isNotEmpty ||
              item.recordingCallId != null && widget.recordingBuilder != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (lines.isNotEmpty)
                    Expanded(
                      child: TextButton(
                        key: ValueKey('receipt-transcript:${item.id}'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: const Color(0xFF086CBD),
                          alignment: Alignment.centerLeft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(_expanded ? '收起通话记录' : '查看通话记录'),
                      ),
                    )
                  else
                    const Spacer(),
                  if (item.recordingCallId case final id?)
                    if (widget.recordingBuilder != null)
                      widget.recordingBuilder!(id, true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
