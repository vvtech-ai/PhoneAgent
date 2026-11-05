enum CloneRequestFailure implements Exception {
  priceChanged('克隆价格已更新，请返回刷新模型价格并重新确认。'),
  modelRequired('请选择声音克隆模型后重新认证。'),
  identityLocked('当前身份已认证，如需更换认证人，请先删除原身份后重新认证'),
  submissionPending('声音克隆正在提交，请稍后重试'),
  phoneLoginRequired('请先使用手机号登录'),
  identityInvalid('身份证号码格式错误'),
  identityIncomplete('认证信息不完整，请返回重新填写'),
  initializationFailed('认证初始化失败，请稍后重新认证。');

  const CloneRequestFailure(this.message);
  final String message;
}
