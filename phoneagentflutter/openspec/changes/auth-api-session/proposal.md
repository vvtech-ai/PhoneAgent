## Why

用户授权接入真实短信登录，并愿意通过弹窗提供验证码。当前只有离线表单，成功结果尚未交接账号会话，需要补齐接口、凭证保存和重启恢复。

## What Changes

- 按 v65 接入 send-code/login，保留路径前缀、业务响应码、邀请码 challenge 和积分字段。
- 增加按环境隔离的安全会话保存与启动恢复；仅持久化成功才离开登录页。
- 用现有工程状态页承接已认证状态，明确首页尚未迁移，不生成假首页；首页/身份初始化等后续保持原需求。
- 加入离线HTTP契约、持久化失败/恢复测试；在用户授权环境进行一次真实验证码登录和重启检查。

## Capabilities

### New Capabilities
- `auth-session`: 真实认证与安全会话生命周期。

### Modified Capabilities
- 无；已有未接入服务失败门禁继续适用于缺少有效配置的情况。

## Impact

auth数据层、会话domain/Controller、Provider/路由和工程状态页；新增flutter_secure_storage固定版本。仅调用现有后台接口，不改后端、数据库、提示词、SIP/ASR/TTS。真实手机号/短信/邀请码/token不进入仓库或日志。
