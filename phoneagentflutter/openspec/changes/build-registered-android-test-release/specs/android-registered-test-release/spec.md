## ADDED Requirements

### Requirement: 测试打包约定必须持久化
项目 MUST 在 AGENTS.md 保存用户批准的测试 Release 环境、登记签名、构建入口、文件命名、运行验证和保留数据安装规则；规则只记录受控文件路径和公开指纹，不得记录凭据值。

#### Scenario: 后续测试包请求
- **WHEN** 用户再次要求生成或安装测试环境 APK
- **THEN** 必须先读取 AGENTS.md 的测试打包规则，并按实际源码、版本和当前设备完成验证与交付

### Requirement: 测试包版本由用户确定
测试 APK 的 versionName 和 versionCode MUST 遵循用户指定或已经批准的递增约定，并参考用户认可的上一包；没有明确约定时 MUST 在打包前确认。MUST NOT 用日期、设备最高版本或历史交付最大号擅自生成版本号，未经用户批准的大号 MUST NOT 成为后续基线。文件名时间戳 MUST 与安装版本号分开。

#### Scenario: 上一认可包是小版本号
- **WHEN** 用户认可的上一包为1.0.52(45)，历史目录另有误设的2026101513
- **THEN** 以用户认可的45作为参考，按用户确定的本次版本构建，不自动沿2026101513递增，也不擅自决定加一

#### Scenario: 设备安装号与用户指定版本冲突
- **WHEN** 设备已有更高安装号，无法保留数据覆盖用户指定版本
- **THEN** 说明限制并等待用户决定，不自动调高版本、改包名、卸载或清数据

### Requirement: 测试 Release 的运行配置与登录可用
AppConfig MUST 接受显式 test 的 HTTPS Release 配置，保持 API、SDK API 和 Runtime 路由独立，任何服务的 HTTP 或不安全 URL MUST 拒绝；dev/local Release 继续拒绝。构建交付 MUST 验证运行配置及登录网关接线，不能仅以 AOT 中出现地址或进程启动替代。

#### Scenario: 显式测试 Release 登录
- **WHEN** APP_ENV=test 且三个服务均为有效 HTTPS 地址
- **THEN** 配置可用，登录请求通过既有签名流程发往配置的测试 SDK 服务
- **WHEN** 任意服务使用 HTTP、含凭据、查询参数或片段
- **THEN** 不建立可用业务配置

### Requirement: 显式 test Release 身份
Android 构建 MUST 只在显式 test 下允许已登记测试身份的 Release，使用 com.vvtech.aiassistant.test 和外部原项目签名，保持登记证书校验；不得回退 debug 签名。

#### Scenario: Release 环境隔离
- **WHEN** 环境为 test 且签名通过登记证书校验
- **THEN** Release 使用 .test 身份及登记签名，且原生 ABI 仅为 ARM64
- **WHEN** 环境未设置或为 dev
- **THEN** 原生产 Release 门禁继续拒绝

### Requirement: 默认 Release 交付与真机验证
测试 APK 构建入口 MUST 默认 Release 并允许显式 Debug，继续校验 test 参数、恢复环境变量并保留供应商受保护库；安装 MUST 使用保留数据方式。

#### Scenario: 测试 Release 成包
- **WHEN** 测试 Release 构建成功
- **THEN** APK 无 debug 标志和调试 kernel，包含 AOT，签名、包名、版本和测试地址经实际读取验证
- **AND** 真机安装后读取版本及首次安装时间，不以卸载或清数据回退
