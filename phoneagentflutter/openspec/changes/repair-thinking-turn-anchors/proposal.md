## Why

用户反馈结果加载后，两张早期 AI 思考卡移动到结果说明下方。现有测试只保护单轮有 assistant committed 时的思考累计，没有覆盖早轮只留下 user 事实、结果补查后失去 assistant 锚点的序列。

## What Changes

- 用真实 ConversationController 连续两轮思考、第三轮结果与 gap 补查重现位置变化。
- 思考优先位于本轮 assistant 前；缺少本轮 assistant 时仍锚定本轮 user 或下一已知轮次，不追加到无关结果后。
- 保留不同轮次内容、原顺序和 ended 状态，不删除思考，不做全局重排。

## Capabilities

### New Capabilities

- `thinking-turn-anchors`: 迟到账本与结果补全下思考所属轮次的位置稳定。

### Modified Capabilities

无。

## Impact

仅客户端局部展示合并与回归；不改后端、接口、提示词、音频或事实存储。对应 AGENTS 的 THINK-01、HISTORY-01、ENTRY-05。诊断包只读，脱敏时序记 verification，不提交用户日志。
