/// Native voice entry wording only; model reasoning remains outside this card.
abstract final class ConversationThinkingPresentation {
  static const _batchSkills = {
    'meeting_notification_v2',
    'business_event_invitation',
    'sales_recommendation',
  };

  static String fallback(String? skillId) =>
      _batchSkills.contains(skillId?.trim().toLowerCase())
      ? '正在理解任务...'
      : 'AI 思考中...';
}
