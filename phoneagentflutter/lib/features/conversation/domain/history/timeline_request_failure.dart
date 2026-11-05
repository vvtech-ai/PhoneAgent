/// Safe wire metadata used for retry presentation; contains no response body.
class TimelineRequestFailure implements Exception {
  const TimelineRequestFailure(
    this.code, {
    required this.retryable,
    required this.recoveryAction,
  });
  final String code, recoveryAction;
  final bool retryable;
  bool get fullResync => recoveryAction == 'FULL_RESYNC';
  String get notice => recoveryAction == 'WAIT_FOR_MIGRATION'
      ? '历史正在迁移，请稍后重试'
      : retryable
      ? '历史同步暂不可用，请重试'
      : '历史同步失败，请重试';
}
