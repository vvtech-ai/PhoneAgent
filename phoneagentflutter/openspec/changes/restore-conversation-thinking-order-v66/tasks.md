## 1. 复现与恢复思考管线

- [x] 1.1 在未提交回退状态下运行思考定向回归，记录 RED：`conversation_thinking_stream_test`、`voice_parity_continuity_test`、`call_confirmation_feedback_test` 共 6 通过 / 9 失败。
- [x] 1.2 恢复 `agent_event_decoder` 的 `data.text` 回退与 `append`/`start` 解码、`conversation_message_store.think/finishThinking`、`conversation_event_flow` 调用、`conversation_message_merge` 插入、`conversation_message_tile` 渲染与 `conversation_content_revision` 字段，对齐原生 v66.0.3 追加语义。
- [x] 1.3 恢复页面 `_currentThinking` 抑制规则与阶段文案回填，使流式思考与占位卡互斥；不触碰同文件中的入口开场白改动与通话相关行。

## 2. 验证与记录

- [x] 2.1 运行思考、道歉入口/生命周期/播报与开场白定向回归：29 项全部通过；`flutter analyze` 无问题；`openspec validate --all` 结果与基线一致（185 通过 / 3 项既有无关失败）。
- [x] 2.2 按仓库规则更新根 `tasks.md` 与 `docs/codex_issue_log.md`，记录本次范围、证据与未验证边界。

## 3. 未完成边界

- [ ] 3.1 Java 侧对照结论待用户确认后另开变更：记忆"本次使用确认"顺序仍由订餐 Skill 约束（`restaurant-booking.md:49-53`），`buildFoodOpening` 的门店名改写字面来自 1.7.5 回移（`backport-v175-call-reliability`），均不由本变更回退。
- [ ] 3.2 真机与真实外呼验收（无设备与真实通话授权，本轮不代验）。
