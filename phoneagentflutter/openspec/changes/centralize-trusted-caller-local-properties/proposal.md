# 可信来电凭据集中到根目录local.properties

## Why
用户确认以与.local同级的单个local.properties保存dev/test/pro三套可信来电凭据，替代三个cloud JSON中的可信字段。

## What Changes
- 根目录local.properties按trustedCaller.<dev|test|pro>.appKey/appSecret保存真实值，并新增精确Git忽略规则。
- Gradle及构建/准备工具使用该唯一凭据来源，保持其他业务配置在既有cloud文件。
- 核对Properties解码值完全一致后删除旧JSON可信字段，禁止回退旧来源。

## Impact
保留Kotlin接口、Flutter UI/共用控件、iOS、SDK映射、版本、签名及生产门禁。更新脱敏示例和隔离构建说明，按用户批准计划验证后提交推送origin/codex/dev；不安装或真实外呼。cloud-pro原有APP_ENV=test待补齐，不猜测生产参数。
