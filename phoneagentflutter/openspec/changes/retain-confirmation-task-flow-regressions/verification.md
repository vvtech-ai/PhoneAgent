# 验证证据

日期：2026-10-20。工作树：`codex/dev`，基础提交 `8445d06f`，并行未提交修改不属于本项。未提交、未推送。

## RED

新增 `test/features/calls/continuous_task_orchestration_test.dart` 后，在未改生产代码时执行：

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test test/features/calls/continuous_task_orchestration_test.dart --reporter compact
```

两用例均失败：用户确认/1.5 秒原有准备期后，`find.text(CallConfirmationPrompt.text)` 期望 1、实际 0，断言原因 `deactivating the card must retain the already shown prompt`。测试使用真实 ConversationController、ConversationSpeechController、ConversationPage、ConfirmationBillingRoute；固定提示在之前的当前卡上确实显示且语音排队一次。外部 fixture 使提示账本稍后经 REST 到达，避免提前补查偶然掩盖缺陷。

## GREEN

最小修复后三项回归覆盖：纯工具历史、单通、同 session 连续两通。确认提示与结果按身份一次；打断只取消旧 playback、不删字；第二轮旧事件不追加正文或语音；两次真实确认/两结果身份有序；实时与恢复、同账本只读详情内容一致；重复恢复零新增命令/语音。

相邻 8 文件共 36 项通过：新增连续回放（当时两项）、call_confirmation_feedback、conversation_ended_tool_cleanup、conversation_call_flow、voice/result_speech_integration、voice/call_confirmation_prompt_integration、call_confirmation_widget、historical_confirmation_prompt。

最终增补纯工具历史与打断断言后执行：

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test test/features/calls/continuous_task_orchestration_test.dart test/features/conversation/conversation_controller_test.dart test/features/conversation/call_confirmation_controller_test.dart test/features/calls/conversation_restored_admission_test.dart test/features/calls/conversation_structured_failure_test.dart test/features/conversation/voice/conversation_speech_integration_test.dart test/features/conversation/current_call_confirmation_gate_test.dart --reporter compact
openspec validate retain-confirmation-task-flow-regressions --strict
```

结果：7 文件 64 项通过；本变更 OpenSpec strict 校验通过；本项生产文件 `git diff --check` 通过。针对本项 3 个生产文件及 2 个测试文件运行 `flutter analyze --no-pub`，5 项无问题。新增/修改中文已按 UTF-8 重新读取，无替换字符。

## 未覆盖边界

- fixture 是合成接口事实，不是线上后端证明；没有真实外呼、部署、APK 或双端真机音频验证。
- SpeechFake 证明调用/排队、取消与代次，不证明可听完成。
- 未持久化本地确认提示的真实会话，恢复正文缺失仍需后端账本证据与独立修复；客户端不从纯工具事实生成虚构对话。
- 跨入口对照本次覆盖单/连续成功结果，其他语义结果及评分刷新由各自变更验证。

## 独立复核后的合同补强

- 新增 same-tool independent prose 回放首轮 RED，收紧 authority 后仍暴露 presentation 用 command/tool 覆盖 plain 正文的第二层问题。保留 plain 自身身份并只协调同文本副本后 GREEN；该点作为支持的 payload 合同防护，不称为已证实线上根因。
- 新增 showOptions / askUser 仅隐藏所属重复 trace 的守护；showOptions 先 RED，修复后两项 GREEN。正式联系人 preview 既有测试从多匹配失败恢复通过，未把 finder 改成 first。
- message_merge、native_presentation_parity 与 contact_task_entry 三文件 30 项通过，独立正文、其他工具和实际选择行为仍有断言。
- 裸 CallConfirmationCard 的旧 width fixture 需迁移：宽度断言继续保留，确认提示由独立正文 owner 的连续 controller/widget 测试守护，不重新引入 executable 控制正文生命周期。
