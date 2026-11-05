## Why

Flutter 的任务评分仅在 provider 首次创建时核对资格。结果先出现、后续终态或结果补全时不会重查，首次失败或暂未符合可永久隐藏评分。task-orchestration-v1.1 的 RATING-01/02 要求原位置补齐；原生 1.6.0 已有 owner 交接刷新及旧响应隔离，v66 基线没有这两项保护。

## What Changes

- 同一结果的有效内容更新驱动现有资格查询；重复渲染不反复查询。
- 恢复 owner 交接刷新；请求代次阻止旧结果覆盖新状态，忙时合并一次刷新。
- 保留真实资格、只读提交、草稿、幂等与单一 owner。

## Capabilities

### New Capabilities
- `late-task-rating-refresh`：同身份结果刷新与迟到资格防护。

### Modified Capabilities
- 无；落实已批准合同，不改变后端资格策略。

## Impact

仅 Flutter feedback 领域投影、控制器、页面接线及实时/详情反馈 builder。无新 API、依赖、数据库、日志正文、提示词、SIP、ASR/TTS 变化；外部服务由测试端口替代，不触发真实电话、评分、积分。以真实 provider/Widget 连续结果回放验证 RATING-01/02/03，后端最终投影及双端设备仍待实测。
