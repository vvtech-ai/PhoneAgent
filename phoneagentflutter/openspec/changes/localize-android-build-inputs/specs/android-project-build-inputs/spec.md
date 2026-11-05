## ADDED Requirements

### Requirement: Android 私有输入固定在工程内
Android dev/test 构建 MUST 分别从本工程 `.local/cloud-dev/device-defines.json` 与 `.local/cloud-test/device-defines.json` 读取环境配置，MUST NOT 新增重复的 `.local/android/config` 来源；测试登记签名 MUST 从 `.local/android/signing` 读取。私有文件 MUST 被 Git 忽略，MUST NOT 回退外部旧目录或默认 debug key。

#### Scenario: 默认测试构建
- **WHEN** 维护者提供工程内 cloud-test/device-defines.json、signing.properties 及相对路径 registered.keystore
- **THEN** 默认 Release 使用原登记测试证书、test 环境、ARM64 和 --pub，保持生产门禁

#### Scenario: 输入缺失或越界
- **WHEN** 输入缺失、环境错误、属性或签名经 canonical 解析后位于工程私有目录之外
- **THEN** 构建立即失败，不读取外部原件或回退 debug 签名

### Requirement: 跨平台入口保护凭据和调用者环境
Windows 与 macOS 测试入口 MUST 使用 Flutter 3.32.0，显式接收版本号，且构建成功或失败后不遗留临时签名环境变量；日志 MUST NOT 输出凭据。

#### Scenario: 子进程失败
- **WHEN** Flutter 构建失败
- **THEN** 入口返回失败状态，调用者环境保持原值，错误只包含安全摘要
