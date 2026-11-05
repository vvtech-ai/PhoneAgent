## ADDED Requirements

### Requirement: 平台和环境必须独立选择凭据
客户端构建 MUST 仅从本工程根 local.properties 读取 trustedCaller.android/ios.dev/test/pro.appKey/appSecret。业务 prod MUST 映射 pro；MUST NOT 回退其他平台/环境、旧参数、cloud JSON、历史原生或父目录。凭据不得输出日志或提交。

#### Scenario: 六种组合
- **WHEN** Android 或 iOS 选择 dev/test/pro
- **THEN** 仅选择对应字段，解析保留 Java Properties 语义，非法或缺失字段脱敏失败

### Requirement: iOS 生成必须与实际构建环境一致
iOS MUST 在 Pod 源文件收集前准备私有源码，编译前重新读取所选配置并校验业务环境与 SDK 环境。dev/test MUST 使用测试 SDK，prod MUST 使用正式 SDK；既有签名/身份/发布门禁 MUST 保留。

#### Scenario: 环境切换及旧生成文件
- **WHEN** 从 dev 切换 test/prod 或根配置发生变化
- **THEN** 编译前重新生成所选凭据，不使用旧环境值；环境冲突时失败

#### Scenario: 独立 iOS 构建
- **WHEN** 准备或编译 iOS
- **THEN** 不依赖 Android 私有业务文件或原生参考仓库，生成文件仅写工程内 ignored 私有路径
