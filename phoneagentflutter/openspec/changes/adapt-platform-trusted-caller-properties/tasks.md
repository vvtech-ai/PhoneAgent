## 实施与问题记录
- [x] 只读核查 codex/dev、干净工作区与旧解析失败，用户批准计划。
- [x] 公共解析与 Android Gradle/打包预检适配。
- [x] iOS 生成、CocoaPods/Xcode 环境选择与编译前校验。
- [x] 更新示例、工程说明和 synthetic 测试。
- [x] 定向测试、静态检查及平台编译检查；分别记录未执行项。
- [ ] 真机授权、实际来电/音频及 Windows PowerShell 执行验收（本次未授权/未具备环境，不归档）。

问题：旧 Android 参数不含平台；旧 iOS 从历史原生提取且仅 test/pro。改动不涉及任务编排事实，不宣称现场根因、真实 SDK/设备验收完成。

## 实施批次
1. 三逻辑文件：公共 Properties 解析、Android Gradle、Python Android 打包入口。
2. 三逻辑文件：iOS 准备脚本、Podfile、Podspec；增加 before_compile 单环境生成及环境门禁。
3. Xcode Runner SDK 搜索环境改为按 PHONEAGENT_IOS_ENV 展开；测试 fixture/API 与示例参数名机械替换独立处理。
4. 新增/扩展 synthetic 配置、Gradle 与 Objective-C 测试；更新文档。Podfile.lock 由 pod install 更新，仅本地 Podspec 和 Podfile 校验值变化，无依赖版本变化。所有手写逻辑文件小于 500 行。

## 2026-10-20 验证
- Python 58 项通过：Properties 8、Android 构建输入 9、准备脚本 7、真实 Gradle 脚本 synthetic harness 9、iOS 新配置/Objective-C 编译 6、iOS 邀请门禁 18、原生 SDK 环境门禁 1。
- Flutter 定向 47 项通过：device_trusted_caller_port、trusted_caller_configured_flow、app_config；flutter analyze --no-pub 无问题。
- 真实根配置六组合仅在内存解析校验通过，未输出值；根文件未修改，仍 ignored/0600/非链接。生成凭据也 ignored/0600，变更文本未包含根凭据值。
- pod install --no-repo-update 通过；真实 Xcode Pod settings：dev/Debug→test、test/Debug→test、prod/Release→pro，宏与 SDK 搜索环境一致。
- Flutter 3.32.0 的 iOS Debug 真机架构不签名构建通过（--no-pub --no-codesign），未安装、未交付签名包。
- 首次无 APP_ENV 的普通模拟器构建被配置门禁拒绝；显式 --no-codesign 后该门禁及新凭据编译通过，但整体模拟器链接因现有 APBToygerFacade 仅含 iOS 真机对象失败，未修改无关身份认证 SDK。
- Ruby Podfile/Podspec 语法、Xcode project plist、OpenSpec 本 change strict、UTF-8、git diff --check 通过。
- Android 未重新成 APK；已执行真实 Gradle 输入脚本九项（含六类输入/安全/环境断言），不是实际 SDK 授权或包运行验收。无 pwsh，Windows fixture 已迁移但未实际运行。真实后端、Android/iOS 画面与实际音频未验，不将编译/mock 作为 DEVICE-01 验收。
- 私有构建诊断仅保留本工程 ignored .local/platform-properties-verification 内，日志权限 0600。未切分支、提交、推送或部署。
