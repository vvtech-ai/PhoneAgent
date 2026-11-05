/// Native welcome semantics; entering login never makes an invalid code valid.
bool inviteWelcomeCanContinue(
  String code, {
  required bool allowBusinessFailure,
}) => allowBusinessFailure && _continuable.contains(code);

String inviteWelcomeFailureMessage(
  String code, {
  required bool allowBusinessFailure,
}) => switch (code) {
  'ACTIVITY_RETIRED' ||
  'INVITE_ACTIVITY_RETIRED' => '本期邀请活动已结束，无法使用此邀请码完成注册。已有账号请返回登录。',
  'EXPIRED' || 'INVITE_EXPIRED' => '邀请码已过期，请使用有效邀请码',
  'EXHAUSTED' || 'QUOTA_EXHAUSTED' || 'INVITE_EXHAUSTED' => '该邀请码名额已用完',
  'REPLACED' || 'INVITE_REPLACED' => '邀请码已被替换，请获取最新邀请码',
  'INVITE_ACTIVITY_CHANGED' => '邀请活动已更新，原邀请码已失效，请获取新邀请码',
  'INVALID_CODE' ||
  'INVITE_INVALID' ||
  'INVITE_CODE_FORMAT_INVALID' ||
  'INVITE_NOT_FOUND' => '邀请码无效，请检查后重试',
  'CONFIG_NOT_PUBLISHED' => '邀请活动尚未发布',
  'CONFIG_SYNCING' || 'CONFIG_SYNC_PENDING' => '活动规则正在同步，请稍后重试',
  'EXTERNAL_INVITE_UNAVAILABLE' => '邀请服务暂不可用，请稍后重试',
  _ => allowBusinessFailure ? '暂时无法加载邀请信息，请重试' : '邀请信息加载失败，请重试',
};

const _continuable = {
  'INVALID_CODE',
  'INVITE_INVALID',
  'INVITE_CODE_FORMAT_INVALID',
  'INVITE_NOT_FOUND',
  'EXPIRED',
  'INVITE_EXPIRED',
  'EXHAUSTED',
  'QUOTA_EXHAUSTED',
  'INVITE_EXHAUSTED',
  'REPLACED',
  'INVITE_REPLACED',
  'INVITE_ACTIVITY_CHANGED',
  'ACTIVITY_RETIRED',
  'INVITE_ACTIVITY_RETIRED',
};
