class InviteFailure implements Exception {
  const InviteFailure(this.code);
  final String code;
  String get message => switch (code) {
    'INVITER_ACCOUNT_CANCELLED' => '邀请码无效',
    'ACTIVITY_RETIRED' ||
    'INVITE_ACTIVITY_RETIRED' => '本期邀请活动已结束，无法使用此邀请码完成注册。已有账号请返回登录。',
    'CONFIG_SYNCING' || 'CONFIG_SYNC_PENDING' => '活动规则正在同步，请稍后重试',
    'EXPIRED' || 'INVITE_EXPIRED' => '邀请码已过期，请使用有效邀请码',
    'EXHAUSTED' || 'QUOTA_EXHAUSTED' || 'INVITE_EXHAUSTED' => '该邀请码名额已用完',
    'REPLACED' || 'INVITE_REPLACED' => '邀请码已被替换，请获取最新邀请码',
    'INVITE_ACTIVITY_CHANGED' => '邀请活动已更新，原邀请码已失效，请获取新邀请码',
    'REGISTRATION_RETRYABLE' => '注册结果正在确认，请重试，勿更换邀请码',
    'REGISTRATION_ABORTED' => '本次注册已终止，可重新确认提交',
    'REGISTRATION_NOT_NEW' => '本次邀请奖励仅限新用户，请返回登录',
    'REQUEST_CONFLICT' => '注册请求与原提交不一致，请核对手机号和邀请码',
    'LOGIN_CHALLENGE_EXPIRED' ||
    'CHALLENGE_EXPIRED' ||
    'INVALID_LOGIN_CHALLENGE' => '手机号验证已失效，请重新获取验证码',
    'INVALID_CODE' ||
    'INVITE_INVALID' ||
    'INVITE_CODE_FORMAT_INVALID' ||
    'INVITE_NOT_FOUND' => '邀请码无效，请检查后重试',
    'CONFIG_NOT_PUBLISHED' => '邀请活动尚未发布',
    'STORAGE' => '无法保存邀请状态，请重试',
    _ => '邀请服务暂不可用，请稍后重试',
  };
}

class InviteActivity {
  const InviteActivity({
    required this.id,
    required this.name,
    required this.rules,
    required this.inviterPoints,
    required this.inviteePoints,
    required this.quota,
    this.subtitle = '',
    this.startAt = '',
    this.endAt = '',
    this.longTerm = false,
    this.bonusEnabled = false,
    this.bonusThreshold = 0,
    this.bonusPoints = 0,
  });
  final String id, name, rules, subtitle, startAt, endAt;
  final int inviterPoints, inviteePoints, quota, bonusThreshold, bonusPoints;
  final bool longTerm, bonusEnabled;
}

class InvitePersonal {
  const InvitePersonal(
    this.eligible,
    this.successful,
    this.inviterPoints,
    this.bonusPoints,
    this.bonusClaimed, {
    this.claimedBonusPoints,
  });
  final int? claimedBonusPoints;
  final bool eligible, bonusClaimed;
  final int successful, inviterPoints, bonusPoints;
}

class InviteOverview {
  const InviteOverview(this.activity, this.personal);
  final InviteActivity? activity;
  final InvitePersonal? personal;
  String get inviterLabel {
    final p = personal;
    if (p == null) return '个人奖励资格暂不可用';
    if (!p.eligible) return '当前账号不享受邀请赠分';
    return p.inviterPoints == 0
        ? '每邀请一位好友暂无赠分'
        : '每邀请一位好友，你得 ${p.inviterPoints} 积分';
  }

  String? get bonusLabel {
    final p = personal;
    if (p?.bonusClaimed == true) {
      return p!.claimedBonusPoints == null
          ? '本期满邀奖励已领取'
          : p.claimedBonusPoints == 0
          ? '本期满邀已达标 · 无赠分'
          : '本期满邀奖励已领取 ${p.claimedBonusPoints} 积分';
    }
    if (activity?.bonusEnabled != true) return null;
    if (p == null) return '满邀奖励状态暂不可用';
    if (!p.eligible) return '当前账号不享受满邀赠分';
    return p.bonusPoints == 0
        ? '本期满邀暂无赠分'
        : '邀满 ${activity!.bonusThreshold} 位再得 ${p.bonusPoints} 积分';
  }
}

class InviteCode {
  const InviteCode(
    this.code,
    this.url,
    this.expiresAt,
    this.used,
    this.reserved,
    this.available,
    this.overview,
  );
  final String code, url, expiresAt;
  final int used, reserved, available;
  final InviteOverview overview;
}

class InviteRecord {
  const InviteRecord(
    this.id,
    this.phone,
    this.registeredAt,
    this.points, {
    this.credited = false,
  });
  final String id, phone, registeredAt;
  final int points;
  final bool credited;
  String get maskedPhone {
    final value = phone.trim();
    if (RegExp(r'^\d{3}\*{4}\d{4}$').hasMatch(value)) return value;
    if (RegExp(r'^\d{11}$').hasMatch(value)) {
      return '${value.substring(0, 3)}****${value.substring(7)}';
    }
    return '已注册用户';
  }
}

class InviteRecords {
  const InviteRecords(this.items, this.total, this.cursor);
  final List<InviteRecord> items;
  final int total;
  final String? cursor;
}

abstract interface class InviteRepository {
  Future<InviteOverview> activity();
  Future<InviteCode> code();
  Future<InviteRecords> records([String? cursor]);
  Future<void> event(String period, String type, String eventId);
}

abstract interface class InviteResolver {
  Future<int> resolve(String code);
}
