## Why
用户确认五项回归修复：国内翻译扣分反馈、输入时最新对话定位、AI处理中禁用附件与模型入口并增加思考间距、套餐明细弹窗、认证完成才计每日次数。

## What Changes
- Flutter 修复四项展示与交互，认证安全提示兼容新旧服务端。
- Java SDK 按服务端确认的认证结果计数，保留运营后台动态限额、账号/身份隔离及完整克隆成功冷却。

## Capabilities
### New Capabilities
- `confirmed-feedback`: 已确认业务结果与交互反馈。

## Impact
涉及 Flutter conversation/commerce/translation/voice_clone 与 Java sdk-api 认证服务。不改真实扣费、数据库结构、供应商训练或音质规则，不打包或部署。
