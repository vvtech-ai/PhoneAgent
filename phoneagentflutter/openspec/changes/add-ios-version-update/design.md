## Decisions
1. 复用 AuthRoute 已登录分支的 StartupUpdateHost，不移动挂载位置；保留账号代次保护和 SharedAppUpdateRepository 合并并发请求。
2. Repository 注入平台类型，校验响应平台一致；历史 Android 响应缺省仍兼容。iOS 更新链接采用独立纯 Dart 策略，空 iosSourceUrl 固定回退 App Store，不读取 apkUrl。允许 HTTPS/itms-apps 且禁止凭据、片段及 APK 地址。
3. iOS 不创建 DeviceUpdateInstallPort，恢复端口返回空。检查记录通过 AppLocalStorage.preference 写沙盒，Android 原选项和 key 不变。
4. iOS 弹窗复用 NativeUpdateDialog，独立组件负责打开忙态和前后台生命周期；平台端口仅负责系统打开。普通更新成功交接后关闭；强更保留弹窗，离开后恢复前台重新检查；失败保留已有 offer 并允许重试。不把打开商店等同安装完成。
5. 每个手写源码微批最多3文件；本轮仅本地修改，不切分支、不提交推送，不覆盖主任务改动。更新 tasks 和问题记录，未设备验收不归档。

## Validation
OpenSpec 全量校验；Flutter 3.32 analyze、更新和关于直接调用方定向测试，覆盖请求平台、链接兜底/非法值、普通/强更、失败重试、频率、未登录边界、生命周期及 Android 回归。iOS 原生桥接编译/整包编译按本机可用环境执行，无法执行明确记录；不安装或触发真实登录、支付、外呼。
