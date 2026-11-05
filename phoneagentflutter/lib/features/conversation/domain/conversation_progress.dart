import 'conversation_messages.dart';

enum ConversationProgress {
  instruction('任务下达'),
  clarification('需求确认'),
  execution('执行通话'),
  result('执行结果');

  const ConversationProgress(this.label);
  final String label;
}

/// Presentation-only projection of the integrated v65 unified-page facts.
/// A stage is neither permission to dial nor a successful business outcome.
abstract final class ConversationProgressPolicy {
  static ConversationProgress resolve(
    List<ConversationMessage> messages, {
    required bool processing,
    bool hasActiveOptions = false,
  }) {
    final lastUser = messages.lastIndexWhere((m) => m.role == MessageRole.user);
    final current = messages
        .skip(lastUser + 1)
        .where((m) => m.role == MessageRole.assistant);
    final assistant = messages.where((m) => m.role == MessageRole.assistant);
    bool singleResult(ConversationMessage m) =>
        m.receipt != null && !m.receipt!.isRunning;
    bool batchResult(ConversationMessage m) =>
        m.batchReceipt != null &&
        m.batchReceipt!.status.toUpperCase() != 'RUNNING';
    final currentResult = current.any((m) => singleResult(m) || batchResult(m));
    // v65 continuingAfterCallResult prevents stale conclusions from winning
    // while processing a new user turn. Current explicit receipts still win.
    final continuing = processing && !currentResult;
    final text = assistant.map((m) => m.text).join('\n');
    if (!continuing &&
        (assistant.any((m) => singleResult(m) || batchResult(m)) ||
            _containsAny(text, ['通话已结束', '任务已完成']))) {
      return ConversationProgress.result;
    }
    final executing = assistant.any(
      (m) =>
          m.receipt?.isRunning == true ||
          m.batchReceipt?.status.toUpperCase() == 'RUNNING',
    );
    // A historical confirmation is not a currently pending agentCallSpec.
    if (executing ||
        current.any((m) => m.confirmation != null) ||
        _containsAny(text, ['任务确认完毕', '拨打预订电话', '正在通话'])) {
      return ConversationProgress.execution;
    }
    if (hasActiveOptions ||
        _containsAny(text, [
          '识别当前任务为',
          '补全',
          '召回候选',
          '搜到的结果',
          '锁定目标',
          '检查预订人联系信息',
          '确认预留联系方式',
          '记录补充要求',
        ])) {
      return ConversationProgress.clarification;
    }
    return ConversationProgress.instruction;
  }

  static bool _containsAny(String text, List<String> values) =>
      values.any(text.contains);
}
