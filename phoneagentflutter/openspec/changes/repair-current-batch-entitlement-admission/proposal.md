## Why

批量权益拒绝后，App 未失效会员与商品目录，展示可能继续停留在旧权益。

## What Changes

新增独立 AgentGateway 装饰器，识别结构化批量权益拒绝后使 catalogControllerProvider 失效；现有 provider 同时承载会员与商品。只刷新一次，不重发命令；原事件、播报、错误和取消保持原样。按登录会话及取消状态隔离延迟回调；不 watch 目录以免重建正在执行的对话。

## Capabilities

### New Capabilities
- `batch-entitlement-refresh`：修复当前批量权益读取及拒绝后的同步。

### Modified Capabilities
无。

## Impact

仅涉及本仓库现有权益读取/任务接线与定向回归；不修改数据表、历史订单、支付、版本或打包配置。
