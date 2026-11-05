## Why

2026-10-17 至 10-18 的未提交回退把会话思考增量管线整体删除：`thinking_delta` 的追加/起始语义、`ConversationMessageStore.think`、流动中的思考卡渲染以及"流式思考存在时不显示阶段占位卡"的抑制规则都不再存在。已验收变更 `align-batch-result-thinking-parity` 的定向回归因此变红：`conversation_thinking_stream_test`、`voice_parity_continuity_test`、`call_confirmation_feedback_test` 共 6 通过 / 9 失败。

用户要求按重构前原生 `test/v66.0.3`（a0bedb12）的实现方向修正会话编排顺序，并保留无关改动、只做最小范围修复。

## What Changes

- 恢复 `thinking_delta` 的嵌套 `data.text` 回退与 `append`/`start` 解码，`thinking_done` 继续按原语义结束当前思考段。
- 思考内容重新作为本轮内单独展示消息，位置保持在本轮 assistant 文本之前；追加按物理行展示，不新增多卡或重排。
- 恢复"当前轮存在进行中思考时不显示阶段占位卡"的抑制规则，占位卡继续在无真实思考内容时回退到技能提示。
- 定向回归与静态检查通过，并按仓库规则记录任务与问题日志。

## Capabilities

### New Capabilities

- `batch-result-thinking-presentation`：`openspec/specs/` 尚无该能力主规格（`align-batch-result-thinking-parity` 仍在 changes 中未归档），本变更补齐其完整要求，并新增原生追加/起始语义、流式思考与占位卡互斥、每轮一张卡且位于本轮文本之前三个场景。

### Modified Capabilities

无。

## Impact

仅 Flutter `lib/features/conversation` 的 domain/presentation/controller 与定向回归。无 Java/Web、数据库、提示词、SIP、ASR/TTS、ledger 事实或原生协议改动；不执行真实外呼、部署或安装。开场白顺序与后台提示词对照结论见 `verification.md`，本次不改动。
