import 'call_dialogue.dart';
import 'call_receipt.dart';
import 'call_receipt_status.dart';

/// Single-call display labels; business outcome remains CallReceiptStatus.
class NativeCallReceiptPresentation {
  const NativeCallReceiptPresentation(this.receipt);
  final CallReceipt receipt;

  CallReceiptOutcome get outcome => CallReceiptStatus.outcome(receipt);
  bool get booking =>
      const {
        'FOOD_ORDERING',
        'RESTAURANT_BOOKING',
        'HOTEL_BOOKING',
        'FOOD',
        'HOTEL',
      }.contains(receipt.metadata['sceneType']?.toUpperCase()) ||
      receipt.fields.any(
        (field) =>
            field.key.toLowerCase() == 'restaurantname' ||
            (field.key.toLowerCase() == 'tasktype' &&
                const {
                  'FOOD_ORDERING',
                  'RESTAURANT_BOOKING',
                }.contains(field.value.toUpperCase())),
      ) ||
      RegExp('订餐|订座|订位|餐厅|饭店|酒店|宾馆|入住|离店|预订|预约|预留|包房|包间|房型').hasMatch(
        [
          receipt.headline,
          receipt.detail,
          receipt.targetName,
          receipt.transcript,
        ].join('\n'),
      );
  bool get task =>
      receipt.fields.isNotEmpty ||
      booking ||
      RegExp('^任务(完成|失败|未完成|部分完成)').hasMatch(receipt.headline);
  bool get failed =>
      outcome == CallReceiptOutcome.failed ||
      outcome == CallReceiptOutcome.cancelled;
  bool get terminalIncomplete =>
      outcome == CallReceiptOutcome.unclear &&
      (receipt.metadata['agentOutcome']?.trim().toUpperCase() == 'UNCLEAR' ||
          receipt.status.trim().toUpperCase() == 'UNCLEAR');
  bool get physicalResultPending {
    final status = receipt.status.trim().toUpperCase();
    if (CallReceiptStatus.isPhysicalOutcomePending(receipt) &&
        status != 'EXECUTION_ERROR') {
      return true;
    }
    if (receipt.isRunning ||
        terminalIncomplete ||
        CallReceiptStatus.hasTechnicalFailure(receipt)) {
      return false;
    }
    if (outcome == CallReceiptOutcome.unclear) return true;
    if (status != 'CALL_COMPLETED' &&
        !const {'COMPLETED', 'ENDED'}.contains(status)) {
      return false;
    }
    return !CallReceiptStatus.hasSemanticOutcome(receipt);
  }

  CallReceiptOutcome get cardOutcome =>
      terminalIncomplete ? CallReceiptOutcome.failed : outcome;
  bool get failureTone => failed || terminalIncomplete;
  bool get executionError =>
      receipt.status.trim().toUpperCase() == 'EXECUTION_ERROR';
  bool get reasonOnly =>
      !executionError &&
      !terminalIncomplete &&
      receipt.fields.isEmpty &&
      booking &&
      (failed || outcome == CallReceiptOutcome.unclear);
  bool get showContact => !failed && outcome != CallReceiptOutcome.unclear;

  String get title {
    if (terminalIncomplete) return task ? '任务未完成' : '通话未完成';
    if (outcome == CallReceiptOutcome.unclear) return '结果确认中';
    if (executionError) return '执行结果';
    if (task) {
      return switch (outcome) {
        CallReceiptOutcome.completed => '任务完成',
        CallReceiptOutcome.failed || CallReceiptOutcome.cancelled => '任务失败',
        _ => '执行结果',
      };
    }
    return receipt.headline.isNotEmpty ? receipt.headline : '执行结果';
  }

  bool get noReservationRequired =>
      receipt.metadata['resultCode']?.trim().toUpperCase() ==
          'NO_RESERVATION_REQUIRED' &&
      outcome == CallReceiptOutcome.completed;

  String get status => terminalIncomplete
      ? '未完成'
      : noReservationRequired
      ? '无需预订，可直接到店'
      : (receipt.fields.isNotEmpty || booking) &&
            outcome == CallReceiptOutcome.completed
      ? '✓任务完成'
      : CallReceiptStatus.label(receipt, booking: booking);

  String get targetLabel {
    if (!booking) return '联系人';
    final hotel =
        receipt.metadata['sceneType']?.toUpperCase().contains('HOTEL') ==
            true ||
        RegExp(
          '酒店|宾馆|入住|离店|房型',
        ).hasMatch('${receipt.targetName}\n${receipt.detail}');
    return hotel ? '酒店' : '餐厅';
  }

  String get reason {
    if (terminalIncomplete) {
      return ReceiptValues.first([
        receipt.metadata['agentReason'] ?? '',
        receipt.metadata['resultReason'] ?? '',
        if (CallDialogue.parse(receipt.detail).isEmpty) receipt.detail,
        receipt.headline,
      ]).replaceFirst(RegExp('^(预订结果|AI代打结果)[:：]\\s*'), '').trim();
    }
    final source = ReceiptValues.first([
      receipt.detail,
      receipt.metadata['agentReason'] ?? '',
      receipt.metadata['resultReason'] ?? '',
      receipt.headline != title ? receipt.headline : '',
    ]).replaceFirst(RegExp('^(预订结果|AI代打结果)[:：]\\s*'), '');
    final lines = source
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return lines
            .where(
              (s) => RegExp(
                '执行异常|失败|未成功|未完成|未接通|不匹配|不符|无空位|没位|取消|结果不明确|无法判断|稍后',
              ).hasMatch(s),
            )
            .firstOrNull ??
        lines.firstOrNull ??
        status;
  }
}
