import 'invite.dart';

/// Activity acquisition messages match AIAssistant1, separately from login.
String inviteActivityFailureMessage(Object error) => switch (error) {
  InviteFailure(code: 'EXTERNAL_INVITE_UNAVAILABLE') => '邀请服务暂不可用，请稍后重试',
  InviteFailure(code: 'CONFIG_SYNCING' || 'CONFIG_SYNC_PENDING') =>
    '活动规则正在同步，请稍后重试',
  InviteFailure(code: 'INVITE_EXPIRED' || 'EXPIRED') => '邀请码已过期，请刷新获取',
  InviteFailure(
    code: 'REPLACED' || 'INVITE_REPLACED' || 'INVITE_ACTIVITY_CHANGED',
  ) =>
    '邀请活动已更新，请刷新获取新邀请码',
  InviteFailure(code: 'QUOTA_EXHAUSTED' || 'EXHAUSTED' || 'INVITE_EXHAUSTED') =>
    '邀请名额已用完',
  InviteFailure(
    code: 'ACTIVITY_DISABLED' ||
        'ACTIVITY_UNAVAILABLE' ||
        'CONFIG_NOT_PUBLISHED',
  ) =>
    '活动暂未开放新邀请码',
  _ => '暂时无法加载邀请信息，请重试',
};
