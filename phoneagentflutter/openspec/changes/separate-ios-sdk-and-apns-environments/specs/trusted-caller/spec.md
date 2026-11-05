## ADDED Requirements

### Requirement: SDK 与 APNs 环境独立验证
SDK 环境 MUST 只决定 SDK 及凭据范围，不得推导系统 APNs 环境。dev/test 本项目交付 MUST 使用开发签名和 development；prod MUST 使用分发签名和 production。

#### Scenario: 系统注册与交付门禁各自负责
- **WHEN** SDK test 且合法 APNs production 配置进行注册单元回放
- **THEN** 不因 SDK test 而阻断系统调用；test 成包仍须通过 development 签名策略检查

### Requirement: 主包与扩展完整一致
最终包 MUST 包含主包对应的 KXPushServiceExtension、KXLiveActivityExtension；Bundle ID、Team、版本、profile 授权与签名 MUST 分别验证。主包 plist、签名和描述文件 APNs MUST 与交付策略一致。

#### Scenario: 扩展缺失或跨环境
- **WHEN** 某扩展缺失、ID/Team/版本错误或 profile 未授权
- **THEN** 在导出前失败，不重签其他身份、不交付

### Requirement: 正式配置未确定时保留临时值并拒绝误交付
构建 MUST 不改写 cloud-pro 的临时配置；APP_ENV 或路由不符合 prod 时 MUST 拒绝正式包。

#### Scenario: pro 临时指向 test
- **WHEN** pro 输入仍包含 APP_ENV=test
- **THEN** 保留原文件并返回脱敏配置错误，不自动提升为正式环境

### Requirement: 构建可追溯且安装前再次校验
每次新构建 MUST 生成不含凭据、Token、账号和完整 profile 的白名单清单。IPA 与清单 MUST 成对验证并导出，清单来源 MUST 来自本次快照，不给历史包补造。

#### Scenario: 错包或清单被替换
- **WHEN** IPA 摘要、环境、版本、主包/扩展事实或目标设备与明确输入不符
- **THEN** 在安装前失败，不卸载、不清数据、不尝试其他包

### Requirement: CI 不依赖私有凭据
环境映射、签名门禁、清单/安装前拒绝逻辑及扩展接线 MUST 有自动回归，CI MUST 不读取生产凭据或调用 SDK/APNs。

#### Scenario: 变更引入配置回退
- **WHEN** 合同回归失败
- **THEN** CI 任务失败，不标记为可交付；原生/扩展检查在 macOS Runner 执行
