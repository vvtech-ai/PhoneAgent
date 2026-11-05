## Why

用户确认实施NF28–NF31邀请功能。当前Flutter仅有旧邀请码登录及钱包，缺少原生新版邀请闭环。

## What Changes

- 固定沿用差异台账Android 0f8879e4、iOS bb9ff349协议和有效入口。
- 新增邀请活动、邀请码、复制/海报、欢迎、注册归因、奖励通知。
- 增加冷热外部链接接收、Android/iOS海报保存及平台配置。
- 保留普通登录与钱包权威余额，新增结构化错误和稳定注册请求标识。

## Capabilities

### New Capabilities
- invite: 邀请展示、注册归因、奖励通知及双端链接和海报能力。

## Impact

影响auth、points、应用装配及新增invite feature；平台增加薄适配。固定Flutter3.32/Dart3.8。真实短信/注册/奖励验收需要测试授权；不修改后台、签名材料或发布保护。原生参考仓库只读。
