import '../../domain/receipts/call_receipt.dart';
import '../../domain/receipts/call_receipt_status.dart';
import '../../domain/receipts/call_dialogue.dart';
import '../../domain/receipts/batch_receipt.dart';
import 'call_receipt_phone_mask.dart';

/// Plain-text projection retained for regression/export callers; shared cards
/// reuse the billing formatter without exposing transport metadata.
abstract final class CallReceiptText {
  static String formatBatch(BatchReceipt receipt) => [
    if (receipt.items.isNotEmpty || !receipt.isExecutionError) ...[
      '批量外呼进度',
      receipt.businessResultUnavailable
          ? '${receipt.completedCount}/${receipt.totalCount} 路执行记录'
          : '${receipt.completedCount}/${receipt.totalCount} 已产生结果',
    ],
    if (receipt.isRunning) '结果陆续返回' else '执行结果',
    if (receipt.businessResultUnavailable)
      '状态：业务结果无法确认'
    else if (receipt.isExecutionError)
      '状态：执行异常',
    if (receipt.headline.isNotEmpty)
      maskCallReceiptPhoneNumbers(receipt.headline),
    if (receipt.detail.isNotEmpty && receipt.detail != receipt.headline)
      maskCallReceiptPhoneNumbers(receipt.detail),
    if (!receipt.isRunning && receipt.items.isNotEmpty)
      receipt.businessResultUnavailable
          ? '${receipt.items.length} 路执行记录'
          : '${receipt.items.length} 路结果 · ${receipt.successCount} 路完成 · ${receipt.items.length - receipt.successCount} 路需关注',
    for (final item in receipt.items) ...[
      '\n${maskCallReceiptPhoneNumbers(item.targetName.isEmpty ? item.phoneNumber : item.targetName)}',
      if (item.phoneNumber.isNotEmpty && item.targetName.isNotEmpty)
        maskCallReceiptPhoneNumbers(item.phoneNumber),
      '状态：${maskCallReceiptPhoneNumbers(_batchLabel(item))}',
      if (item.headline.isNotEmpty) maskCallReceiptPhoneNumbers(item.headline),
      if (item.detail.isNotEmpty && item.detail != item.headline)
        maskCallReceiptPhoneNumbers(item.detail),
      for (final field in item.fields)
        '${maskCallReceiptPhoneNumbers(field.label)}：${maskCallReceiptPhoneNumbers(field.value)}',
      if (item.transcript.isNotEmpty)
        '通话记录：\n${maskCallReceiptPhoneNumbers(item.transcript)}',
      for (final (index, bill) in item.billing.indexed) ...[
        if (item.billing.length > 1) '第 ${index + 1} 次结算',
        ...billingRows(bill),
      ],
    ],
  ].join('\n');

  static String _batchLabel(BatchReceiptItem item) {
    if (item.outcome != BatchItemOutcome.running) {
      final business = item.fields
          .where((f) => f.key == 'businessResult')
          .firstOrNull;
      if (business != null) return business.value;
    }
    return switch (item.outcome) {
      BatchItemOutcome.success => '已完成',
      BatchItemOutcome.failed => '未完成',
      BatchItemOutcome.unclear => '待确认',
      BatchItemOutcome.cancelled => '已取消',
      BatchItemOutcome.running => '进行中',
    };
  }

  static String format(CallReceipt receipt) {
    final dialogue = CallDialogue.parse(receipt.transcript);
    return [
      '通话结果',
      '状态：${CallReceiptStatus.label(receipt)}',
      if (receipt.targetName.isNotEmpty)
        '联系人：${maskCallReceiptPhoneNumbers(receipt.targetName)}',
      if (receipt.phoneNumber.isNotEmpty)
        '电话：${maskCallReceiptPhoneNumbers(receipt.phoneNumber)}',
      if (receipt.headline.isNotEmpty &&
          receipt.headline != receipt.status &&
          receipt.headline != CallReceiptStatus.label(receipt))
        maskCallReceiptPhoneNumbers(receipt.headline),
      if (receipt.detail.isNotEmpty && receipt.detail != receipt.headline)
        maskCallReceiptPhoneNumbers(receipt.detail),
      for (final field in receipt.fields)
        '${maskCallReceiptPhoneNumbers(field.label)}：${maskCallReceiptPhoneNumbers(field.value)}',
      if (dialogue.isNotEmpty) ...[
        '\n通话转写',
        for (final line in dialogue)
          '${line.role == CallDialogueRole.assistant ? 'AI' : '对方'}：${maskCallReceiptPhoneNumbers(line.text)}',
      ],
      if (receipt.billing case final billing?) ...billingRows(billing),
    ].join('\n');
  }

  static List<String> billingRows(ReceiptBilling billing) => [
    for (final (label, value) in billingFields(billing)) '$label：$value',
  ];

  static List<(String, String)> billingFields(ReceiptBilling billing) {
    if (!const {
      'SETTLED',
      'RELEASED',
    }.contains(billing.state.trim().toUpperCase())) {
      return [('结算状态', '待核对')];
    }
    final blockMs = billing.blockDurationMs;
    final duration = blockMs != null && blockMs > 0 && blockMs % 1000 == 0
        ? '${blockMs ~/ 1000} 秒'
        : '$blockMs 毫秒';
    return [
      if (billing.durationSeconds case final seconds?) ('计费时长', '$seconds 秒'),
      if (billing.firstMinutePoints != null &&
          blockMs != null &&
          billing.blockPoints != null)
        (
          '模型费率',
          '首分钟 ${billing.firstMinutePoints}，之后每 $duration ${billing.blockPoints}',
        ),
      if (billing.chargedPoints case final points?) ('扣除积分', '$points'),
      if (billing.remainingPoints case final points?)
        ('剩余积分', _groupDigits(points)),
    ];
  }

  static String _groupDigits(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}
