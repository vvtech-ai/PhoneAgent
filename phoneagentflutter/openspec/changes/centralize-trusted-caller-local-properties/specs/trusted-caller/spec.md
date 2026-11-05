## ADDED Requirements

### Requirement: 可信来电凭据必须集中在根目录Properties文件
Android可信来电凭据 MUST 仅从工程根目录local.properties读取，按trustedCaller.dev/test/pro.appKey/appSecret区分环境；MUST NOT 回退cloud JSON、历史源码、android/local.properties或父工作区。根目录真实文件 MUST 被Git忽略，读取代码和脱敏示例 MUST 可提交。

#### Scenario: 选择环境
- **WHEN** 选择dev/test/pro构建
- **THEN** 从根文件读取对应两个字段，并沿用原SDK环境映射和BuildConfig接线

#### Scenario: 迁移带特殊字符的值
- **WHEN** 原凭据包含空格、反斜杠、分隔符或Unicode字符
- **THEN** Properties编码及所有实际读取路径解码后保持原值，不输出私有值

#### Scenario: 缺失或无效私有输入
- **WHEN** 根文件缺失、为符号链接、Properties格式错误，或所选字段缺失/空白/含换行或NUL
- **THEN** 构建明确失败且错误不含凭据，不读取其他环境或旧JSON补齐

### Requirement: 单文件迁移必须保留业务和发布边界
迁移 MUST 先核对根文件中的实际解码值再移除旧JSON可信字段；其他cloud业务字段、android/local.properties、iOS、UI、版本、签名及生产Release门禁 MUST 保持不变，Dart/Android及cloud业务环境不一致 MUST 拒绝。

#### Scenario: cloud-pro仍为测试业务配置
- **WHEN** 选择pro且cloud-pro的APP_ENV仍为test
- **THEN** 拒绝该业务环境，不因根文件存在pro可信字段就开放生产构建

#### Scenario: 隔离构建
- **WHEN** 在隔离源码根目录构建
- **THEN** 仅使用该目录自己的local.properties，并沿用既有临时目录生命周期
