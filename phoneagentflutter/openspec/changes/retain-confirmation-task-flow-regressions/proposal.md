# 确认提示与连续通话回归补齐

## Why

旧 Android 已有确认提示保留及同会话连续 attempt 回归。Flutter 现有用例分别检查确认回显、工具清理与旧结果隔离，未把显示、执行、真实语音控制器及恢复串成连续回放。新增回归证实：当前确认提示仅由 `CallConfirmationCard.executable` 临时生成，卡失活时已显示正文消失。

## What Changes

- 实时收到有效确认请求时，消息 store 按 command/tool 身份保存现有固定提示；与卡片执行资格分离。
- 确认卡只展示确认快照；语音仍由既有 SSE 语音控制器驱动，不因新增正文再播一遍。
- 补真实 controller 的一通/连续两通、重复事件、打断、原结果保留与恢复回归。
- 相同 fixture 比较实时、恢复与只读详情的业务内容。纯工具历史不补造正文或语音。

## Capabilities

### New Capabilities

- `conversation-confirmation-timeline`: 明确已显示确认提示在连续执行中的保留回归。

### Modified Capabilities

无公共接口或后端行为变更。

## Impact

仅 Flutter 消息 owner、确认卡渲染、局部消息合并 / 表示规则与专用测试。保留确认门禁、账本权威、原任务身份、计费快照与 SSE 语音入口；不改数据库、接口、SIP、ASR/TTS 协议、后台任务或真实外呼。共享模块只修同身份副本协调与结构卡重复轨迹，不做全局重排。
