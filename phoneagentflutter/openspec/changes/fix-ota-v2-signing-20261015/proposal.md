## Why
Android关于页版本检查失败。原生aiassistant_app对OTA显式保留v2/HMAC-SHA256，Flutter统一C1缺少此例外。用户日志四次401无路由，不能认定全部为OTA。

## What Changes
- 仅SDK api/ota/check采用v2，复用部署SDK凭据，其他请求保持C1。
- OTA401分类为请求拒绝，不刷新或清除登录。
- 增加脱敏OTA请求与响应解析阶段诊断。
- 保持Flutter关于页、共用控件、启动/手动共享及强制升级安全规则。

## Capabilities
### New Capabilities
- `ota-request-signing`: OTA签名兼容和安全诊断。
### Modified Capabilities
无。

## Impact
网络签名适配、OTA仓库、诊断及定向测试；不改原生UI、后端、凭据配置、发布策略，不安装、不提交推送、不归档。
