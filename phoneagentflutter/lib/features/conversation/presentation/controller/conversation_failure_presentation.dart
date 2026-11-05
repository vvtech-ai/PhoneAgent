import '../../domain/agent_failure.dart';
import 'conversation_state.dart';

abstract final class ConversationFailurePresentation {
  static ConversationState apply(
    ConversationState state,
    Object? failure, {
    required bool hasActiveCall,
    bool recoverableInput = false,
  }) {
    final execution = failure is AgentFailure && !failure.isNetworkFailure;
    return state.copy(
      phase: recoverableInput || (execution && !hasActiveCall)
          ? ConversationPhase.ready
          : ConversationPhase.recoveryRequired,
      activity: '',
      clearOptions: true,
      notice: recoverableInput
          ? '网络连接中断，已保留本轮内容，可继续说话或输入；不会自动重发。'
          : hasActiveCall
          ? '正在确认通话状态；不会自动重复提交任务。'
          : failure is AgentFailure
          ? _message(failure)
          : '连接中断或响应异常，请同步历史后继续；不会自动重复提交任务。',
    );
  }

  // Server details can contain upstream endpoints or request content. Display
  // the fixed v65 message for a recognized code, never a raw diagnostic string.
  static String _message(AgentFailure failure) {
    if (failure.errorCode.toUpperCase() == 'BUSINESS_REJECTED') {
      return '本次操作未完成，请检查后重试';
    }
    if (failure.errorCode.toUpperCase() == 'POINTS_INSUFFICIENT_BALANCE') {
      return '积分不足，请补充积分后重试';
    }
    if (failure.isNetworkFailure) return '网络连接异常，请同步历史后继续。';
    return switch (failure.errorCode.toUpperCase()) {
      'PHONE_CAPACITY_UNAVAILABLE' => '电话线路正忙，本次未拨出，请稍后重试',
      'MODEL_TIMEOUT' => '服务响应超时，请稍后重试',
      'MODEL_RATE_LIMIT' => '服务繁忙，请稍后重试',
      'MODEL_PROVIDER_UNAVAILABLE' => 'AI 服务暂时不可用，请稍后重试',
      'MODEL_CONTEXT_LIMIT' => '当前任务内容较长，已尝试压缩上下文，请精简要求后继续',
      'MODEL_AUTH_OR_QUOTA' => 'AI 服务配置异常，请稍后再试',
      'MODEL_BAD_REQUEST' || 'INVALID_MODEL_HISTORY' => '当前会话上下文异常，请新建任务后重试',
      'TOOL_EXECUTION_FAILED' => '任务执行失败，请调整要求后重试',
      'LEDGER_OR_STORAGE_FAILED' => '任务状态保存失败，请稍后重试',
      'RESPONSE_SERIALIZATION_FAILED' => '服务返回异常，请稍后再试',
      'EMPTY_MODEL_RESPONSE' => 'AI 暂时没有返回有效回复，请稍后重试',
      _ => '服务暂时不可用，请稍后再试',
    };
  }
}
