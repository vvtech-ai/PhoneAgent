# 设计与职责

- scripts/trusted_caller_properties.py：显式 platform + environment 的唯一 Python 解析接口，平台仅 android/ios，环境仅 dev/test/pro；不回退旧字段。
- android/trusted-caller.gradle 与打包预检：Android 前缀；保持 BuildConfig、cloud APP_ENV、Dart 环境和私有路径门禁。
- tool/prepare_trusted_caller_credentials.py：iOS 单环境私有生成；移除历史原生凭据源，保留 ignored、非链接、0600、原子替换。生成时不接触 Android 输入。
- ios/Podfile、Podspec 与 Xcode 设置：生成源码先于 Pod 源文件收集，编译前强制重读根配置；dev/test 使用测试 SDK，prod 使用正式 SDK。PHONEAGENT_IOS_ENV 默认 Debug/Profile dev、Release prod，test 显式覆盖；APP_ENV 不一致或 SDK 映射不一致失败。无 APP_ENV 的 dev 不签名编译沿用邀请门禁。
- SDK、签名、应用身份、UI 和任务编排保持不变；不修改根私有配置或提交生成凭据。历史变更不重写。
- 分批不超过三个手写逻辑文件，测试与机械参数名替换独立记录。覆盖六组合、跨平台隔离、旧键拒绝、解析一致性、切换与构建门禁，不将 mock/编译等同真实授权。
