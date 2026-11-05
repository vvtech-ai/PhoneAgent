import 'trusted_caller.dart';

enum TrustedCallerOperation { prepare, guide, open, refresh }

String trustedCallerFailureMessage(Object error, TrustedCallerOperation stage) {
  final code = error is TrustedCallerFailure ? error.code : '';
  return switch (code) {
    'SDK_ACCOUNT_INVALID' || 'SDK_ACCOUNT_UNCONFIRMED' => '可信来电账号同步未完成，请重试',
    'SDK_SURFACE_INVALID' => '可信来电环境或账号配置不匹配，请检查配置',
    'SDK_RUNTIME_MISSING' => '可信来电组件依赖缺失，请更新安装包',
    'SDK_CREDENTIALS_MISSING' => '可信来电组件配置缺失，请更新安装包',
    'SDK_RUNTIME_LINKAGE_FAILED' => '可信来电组件加载失败，请更新安装包',
    'SDK_PREPARE_FAILED' || 'SDK_INITIALIZATION_EXCEPTION' => '可信来电组件初始化失败，请重试',
    'SDK_UNAVAILABLE' || 'SDK_NOT_CONFIGURED' => '可信来电组件暂不可用，请重试',
    'SDK_SURFACE_BUSY' => '可信来电页面正在打开，请稍后重试',
    'SDK_SIM_CLEANUP_UNCONFIRMED' ||
    'SDK_INCOMING_CLEANUP_UNCONFIRMED' => '旧账号可信来电数据清理未完成，请重试',
    'SDK_SIM_SYNC_UNCONFIRMED' => '可信来电号码同步未完成，请重试',
    'SDK_INVALID_REPORT' => '可信来电组件返回异常，请重试',
    'SDK_SURFACE_CLOSED' => '可信来电页面已失效，请重新打开',
    'SDK_LAUNCH_UNCONFIRMED' => '可信来电页面未成功打开，请重试',
    _ => switch (stage) {
      TrustedCallerOperation.prepare => '可信来电组件准备失败，请重试',
      TrustedCallerOperation.guide => '可信来电说明记录未完成，请重试',
      TrustedCallerOperation.open => '可信来电设置未完成，请重试',
      TrustedCallerOperation.refresh => '可信来电状态读取失败，请重试',
    },
  };
}
