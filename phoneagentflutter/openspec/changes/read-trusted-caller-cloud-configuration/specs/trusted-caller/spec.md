## ADDED Requirements

### Requirement: Android可信来电凭据必须来自所选cloud环境配置
Android MUST 按 dev/test/pro 分别读取工程内 `.local/cloud-dev/device-defines.json`、`.local/cloud-test/device-defines.json`、`.local/cloud-pro/device-defines.json` 的 TRUSTED_CALLER_APP_KEY 和 TRUSTED_CALLER_APP_SECRET；MUST NOT 从其他环境回退、原生历史提交或硬编码源码获取。真实凭据 MUST 被 Git 忽略，读取器及脱敏规范 MUST 可提交。

#### Scenario: 选择测试环境
- **WHEN** 显式选择 test 构建并提供有效 cloud-test 配置
- **THEN** 构建注入该文件的可信来电凭据，main 源集读取器只接受当前 SDK test 标签

#### Scenario: 缺失或错误的配置
- **WHEN** 文件缺失、路径为符号链接、JSON无效、凭据非字符串/空白/含换行，或者 APP_ENV 与构建环境不匹配
- **THEN** 构建失败且错误不包含私有内容，不回退其他环境

#### Scenario: 原生与Dart环境冲突
- **WHEN** Dart 显式 APP_ENV 与 Android 选择不同
- **THEN** 构建在原生配置阶段失败，不输出凭据

#### Scenario: 切换环境或更新凭据
- **WHEN** 同一工作区在 dev/test/pro 间切换，或者修改所选环境凭据
- **THEN** 原生构建字段使用当前文件值，不复用上一构建凭据

### Requirement: 三环境读取不得放宽原有发布与平台边界
Android MUST 保留 dev/test 对应 SDK test、生产正式包对应 SDK pro 的映射，pro 的 Dart APP_ENV MUST 为 prod。生产 Release 门禁、签名、版本、iOS及Flutter UI MUST 保持现状；MUST NOT 把目录名作为生产配置有效的证据。

#### Scenario: cloud-pro仍是测试参数
- **WHEN** cloud-pro 中 APP_ENV 仍为 test
- **THEN** 拒绝生产配置，不猜测或复制测试服务地址为生产值

#### Scenario: 旧Android-only准备命令
- **WHEN** 执行旧工具的 Android-only 入口
- **THEN** 仅校验选中cloud配置，不生成凭据源码、不读取原生Git、不修改iOS生成文件或旧私有清单
