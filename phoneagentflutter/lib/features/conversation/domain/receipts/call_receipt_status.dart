import 'call_receipt.dart';

enum CallReceiptOutcome { completed, failed, cancelled, unclear, running }

/// Business outcome follows v65 TaskCallResultDisplayPolicy, not physical EOF.
abstract final class CallReceiptStatus {
  static String _normalize(String? value) => value?.trim().toUpperCase() ?? '';
  static String _agentOutcome(CallReceipt r) => _normalize(
    ReceiptValues.first([
      for (final key in const [
        'agentOutcome',
        'reportCallOutcome',
        'callOutcome',
        'outcome',
        'agent_outcome',
      ])
        r.metadata[key] ?? '',
    ]),
  );

  static bool hasSemanticOutcome(CallReceipt r) => const {
    'SUCCESS',
    'COMPLETED',
    'FAILED',
    'UNCLEAR',
    'USER_CANCELLED',
    'USER_CANCELED',
    'NEEDS_RECALL',
  }.contains(_agentOutcome(r));

  static bool isPhysicalOutcomePending(CallReceipt r) =>
      r.metadata['physicalTerminalOnly'] == 'true' ||
      r.metadata['physicalOnlyOutcomePending'] == 'true';

  static CallReceiptOutcome outcome(CallReceipt r) {
    if (_normalize(r.status) == 'EXECUTION_ERROR') {
      return CallReceiptOutcome.failed;
    }
    if (isPhysicalOutcomePending(r)) return CallReceiptOutcome.unclear;
    switch (_agentOutcome(r)) {
      case 'SUCCESS':
      case 'COMPLETED':
        return CallReceiptOutcome.completed;
      case 'USER_CANCELLED':
      case 'USER_CANCELED':
        return CallReceiptOutcome.cancelled;
      case 'FAILED':
      case 'NEEDS_RECALL':
        return CallReceiptOutcome.failed;
      case 'UNCLEAR':
        return CallReceiptOutcome.unclear;
    }
    final code = _normalize(r.metadata['resultCode']);
    if (code == 'SUCCESS_CONFIRMED' || code == 'NO_RESERVATION_REQUIRED') {
      return CallReceiptOutcome.completed;
    }
    if (code.startsWith('FAILED') ||
        const {
          'CALL_FAILED',
          'CALL_INTERRUPTED',
          'NO_EFFECTIVE_DIALOGUE',
          'NO_ANSWER',
          'BUSY',
          'REJECTED',
          'TIMEOUT',
          'MERCHANT_REQUESTED_CALLBACK',
        }.contains(code)) {
      return CallReceiptOutcome.failed;
    }
    if (code == 'INCOMPLETE_OR_UNCLEAR') return CallReceiptOutcome.unclear;
    final status = _normalize(r.status);
    if (r.isRunning) return CallReceiptOutcome.running;
    if (const {
      'CANCELLED',
      'CANCELED',
      'USER_CANCELLED',
      'USER_CANCELED',
      'USER_INTERRUPTED',
      'CALL_CANCELLED',
    }.contains(status)) {
      return CallReceiptOutcome.cancelled;
    }
    if (const {
      'FAILED',
      'ERROR',
      'FAIL',
      'CALL_FAILED',
      'CALL_REJECTED',
    }.contains(status)) {
      return CallReceiptOutcome.failed;
    }
    if (const {
      'COMPLETED',
      'SUCCESS',
      'DONE',
      'FINISHED',
      'CALL_COMPLETED',
    }.contains(status)) {
      final source = [
        r.headline,
        r.detail,
        r.metadata['agentReason'] ?? '',
        r.metadata['resultReason'] ?? '',
      ].join('\n');
      if (RegExp(
        r'\b(FAILED|FAIL|ERROR|INCOMPLETE|NO_ANSWER|REJECTED|TIMEOUT)\b|'
        '任务失败|未完成|失败|未成功|未订到|没订到|没有订到|未接通|无人接听|无空位|满位|拒绝|无法完成|稍后再联系',
        caseSensitive: false,
      ).hasMatch(source)) {
        return CallReceiptOutcome.failed;
      }
    }
    return CallReceiptOutcome.unclear;
  }

  static String label(CallReceipt r, {bool booking = false}) {
    if (isPhysicalOutcomePending(r)) return '结果未确认';
    if (r.metadata['resultCode'] == 'POINTS_INSUFFICIENT_BALANCE' ||
        r.headline.contains('积分不足')) {
      return '积分不足';
    }
    return switch (outcome(r)) {
      CallReceiptOutcome.completed => booking ? '任务完成' : '完成',
      CallReceiptOutcome.running => '进行中',
      CallReceiptOutcome.unclear => '结果未确认',
      CallReceiptOutcome.failed ||
      CallReceiptOutcome.cancelled => hasTechnicalFailure(r) ? '执行异常' : '未完成',
    };
  }

  static bool hasTechnicalFailure(CallReceipt r) {
    if (_normalize(r.status) == 'EXECUTION_ERROR') return true;
    if (const {
      'FAILED',
      'UNCLEAR',
      'NEEDS_RECALL',
      'USER_CANCELLED',
      'USER_CANCELED',
    }.contains(_agentOutcome(r))) {
      return false;
    }
    final code = _normalize(r.metadata['resultCode']);
    if (const [
          'NO_ANSWER',
          'BUSY',
          'REJECTED',
          'USER_CANCEL',
        ].any(code.contains) ||
        code == 'INCOMPLETE_OR_UNCLEAR' ||
        code == 'MERCHANT_REQUESTED_CALLBACK') {
      return false;
    }
    if (const {
      'REMOTE_BYE',
      'USER_CANCELLED',
      'USER_CANCELED',
    }.contains(_normalize(r.metadata['terminationCause']))) {
      return false;
    }
    final source = [
      r.status,
      r.headline,
      r.detail,
      ...r.metadata.values,
    ].join('\n');
    final upper = source.toUpperCase();
    return const [
          'NETWORK',
          'TIMEOUT',
          'SIP_ERROR',
          'PHONE_AGENT_ERROR',
          'MODEL_ERROR',
          'SERVICE_UNAVAILABLE',
          'HTTP_ERROR',
          'TECHNICAL',
        ].any(upper.contains) ||
        upper == 'ERROR' ||
        upper.endsWith('_ERROR') ||
        const [
          '网络异常',
          '网络错误',
          '执行异常',
          '模型服务异常',
          '外呼通道异常',
          '服务不可用',
          '连接失败',
          '真实 SIP 未启用',
          'phone agent 未 ready',
          '超时',
        ].any(source.contains);
  }
}
