## Context

当前工作树（未提交）删除了思考管线的六处代码：`agent_event_decoder` 的追加/起始解码、`conversation_message_store` 的 `think`/`finishThinking`、`conversation_event_flow` 的三处调用、`conversation_message_merge` 的思考插入、`conversation_message_tile` 的思考卡渲染、`conversation_content_revision` 的思考字段。页面侧同时把占位卡条件改成"阶段文本等于'正在思考…'"，失去了与真实思考互斥的能力。

重构前原生 `D:\project\aiassistant` 的 `test/v66.0.3@a0bedb12` 为对照基线：

- `AgentStreamSseEventParser.kt:94-98`：`text = data["text"] ?: map["text"]`，`append = true`，`start = data["start"] ?: map["start"]`。
- `AgentStreamBasicStepReducer.kt:11-36`：思考在同一轮内按 `append`/`start` 换行追加，`thinking_done` 只结束当前段。
- `PureVoiceThreadList.kt:244-254`：思考文本按物理行渲染为一张卡，位于本轮内容内。
- `PureVoiceThreadRenderState.kt:144-146`：`showProcessingPlaceholder = processingTurn && ... && !hasActiveStreamingThinking()`，流式思考期间不显示占位卡。

## Goals / Non-Goals

Goals：恢复原生追加语义与"每轮一张思考卡 + 流式期间不叠加占位卡"，让已验收回归恢复绿色。

Non-Goals：本变更只负责思考，不定义开场清理或首页就绪规则。原“有消息即不渲染本地开场卡”备注已被用户批准的 `task-orchestration-v1` 替代；开场 / 正文保留与恢复按该合同和有效 delta 执行。不改 Java 提示词，不新增竞争投影或全局重排；真机与真实外呼仍待验。

## Decisions

1. 直接恢复 HEAD 的思考管线（解码、存储、事件流、合并插入、卡片渲染、内容修订），即把未提交回退中"删除思考"的部分还原，改动面限定在这 6 个文件与该页面的 4 处相关行。
2. 思考插入位置保持"本轮第一条 assistant 消息之前"，与原生"思考卡在本轮文本之上"一致；思考文本按 `\n` 拆行传给 `NativeThinkingCard`。
3. 页面恢复 `_currentThinking`：本轮最后一条用户命令存在 `thinking.processing == true` 时，阶段占位卡不渲染；无真实思考内容时继续使用 `ConversationThinkingPresentation.fallback`。
4. 先复现 RED 再修复：修复前 3 个定向测试文件 6 通过 / 9 失败；修复后同一组加道歉与开场白回归共 29 项全部通过。

## Risks / Trade-offs

恢复后思考卡会重新出现在执行过程中，这与用户早先"不要多张卡"的感受不冲突：每轮只有一张，文本按行累计，位置固定在本轮文本之前；若用户仍要求完全不显示思考内容，可只回退该增量的渲染接线而不影响解码与台账。

## Verification

见 `verification.md`：RED/GREEN 数字、命令、静态分析与规格校验结果，以及 Java/开场白侧的只读对照结论。
