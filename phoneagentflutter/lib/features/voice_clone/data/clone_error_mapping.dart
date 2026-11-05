import '../../../core/network/account_session.dart';
import '../domain/clone_request_failure.dart';

const cloneBusinessCodes = {
  '克隆价格已更新，请刷新价格后重试',
  'modelId不能为空',
  'modelId 不能为空',
  '请选择声音克隆模型',
  '当前身份已认证，如需更换认证人，请先删除原身份后重新认证',
  '声音克隆正在提交，请稍后重试',
  '请先使用手机号登录',
  '身份证号码格式错误',
  '认证信息不完整',
  '阿里云跟读认证初始化失败',
};
CloneRequestFailure? cloneBusinessFailure(String code) => switch (code) {
  '克隆价格已更新，请刷新价格后重试' => CloneRequestFailure.priceChanged,
  'modelId不能为空' ||
  'modelId 不能为空' ||
  '请选择声音克隆模型' => CloneRequestFailure.modelRequired,
  '当前身份已认证，如需更换认证人，请先删除原身份后重新认证' => CloneRequestFailure.identityLocked,
  '声音克隆正在提交，请稍后重试' => CloneRequestFailure.submissionPending,
  '请先使用手机号登录' => CloneRequestFailure.phoneLoginRequired,
  '身份证号码格式错误' => CloneRequestFailure.identityInvalid,
  '认证信息不完整' => CloneRequestFailure.identityIncomplete,
  '阿里云跟读认证初始化失败' => CloneRequestFailure.initializationFailed,
  _ => null,
};
Future<T> cloneRequest<T>(Future<T> Function() send) async {
  try {
    return await send();
  } on ApiCodeFailure catch (error) {
    final failure = cloneBusinessFailure(error.code);
    if (failure != null) throw failure;
    rethrow;
  }
}
