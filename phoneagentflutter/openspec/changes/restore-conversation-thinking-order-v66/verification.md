# Verification

## RED（未提交回退状态）

```
flutter test test/features/conversation/conversation_thinking_stream_test.dart \
  test/features/conversation/voice_parity_continuity_test.dart \
  test/features/conversation/call_confirmation_feedback_test.dart
→ 00:05 +6 -9: Some tests failed.
```

首个失败样例：`call_confirmation_feedback_test.dart:207` 期望流式思考期间不出现 `conversation-thinking` 占位卡，实测出现 1 个。

## GREEN（本次修复后）

```
flutter test <上述3个文件 + apology_entry_controller_test + apology_opening_speech_test
  + apology_precheck_lifecycle_test + shell_apology_precheck_test + native_conversation_opening_test>
→ 00:07 +29: All tests passed!

flutter analyze → No issues found!
openspec validate --all → 185 passed, 3 failed（与基线相同的既有无关项）
```

## 改动范围

- 恢复：`agent_event_decoder.dart`、`conversation_message_store.dart`、`conversation_event_flow.dart`、`conversation_message_merge.dart`、`conversation_message_tile.dart`、`conversation_content_revision.dart`（思考管线）。
- 定点恢复：`conversation_page.dart` 的 `_currentThinking`/`_thinking`、阶段值、思考气泡文案共 4 处。
- 未改动：入口开场白相关未提交改动（`conversation_entry_opening.dart` 删除与 `conversation_page.dart` 对应块）、Java/Web、提示词、SIP/ASR/TTS。

## 只读对照结论（不改动）

1. 开场白顺序：当前工作树已符合原生 v66.0.3——有消息时不渲染本地入口开场卡，开场白随首次提交由后台 `initial-opening:` 落库一次；`shell_apology_precheck_test` 断言道歉入口只出现一张同意卡且同意前不发命令，实测通过。
2. 记忆"本次使用确认"顺序：规则仍在订餐 Skill 内约束（`aiassistant-agent-sse/src/main/resources/skills/restaurant-booking.md:49-53`："本轮未指定而 `<user_memories>` 中有适用预订联系人时……未获明确同意或选择前不得将其姓名和手机号填入 makeCall 或拨号确认卡"），Java 策略只注入 `<restaurant_contact_memory_state>` 状态标签，属提示词去重（e95ebaa0），不是顺序丢失。
3. `buildFoodOpening` 门店名改写：来自 `821e0619`（1.7.5 回移，伴随 `openspec/changes/backport-v175-call-reliability`），与 `feature/test_v1.7.0` 的 script 原样返回不同。回退将推翻已验收变更，待用户决定，不在本变更内处理。

## 未验证边界

未做真机、真实模型会话、真实外呼与安装；思考卡"最近三物理行自动滚动"沿用既有 `NativeThinkingCard` 行为，本变更未新增其实现。
