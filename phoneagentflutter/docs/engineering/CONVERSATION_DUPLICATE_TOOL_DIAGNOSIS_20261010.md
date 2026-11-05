# 完成后重复提问与 make_call 进度残留排查

## 结论与边界

2026-10-10用户截图：同一补充问题出现两个气泡，外呼结果之后仍出现 make_call() 与提交中提示；播报期间未听见重复。已用合成数据复现两处客户端缺陷并修复。此次不修改Java、数据库、模型提示词或部署；后端同事可按下文核对运行契约。

截图和服务器原始日志含真实业务资料，不纳入仓库，也不转成测试fixture。现有日志未提供完整SSE/timeline payload，不能据此保证所有服务端事件绝无重复；目前没有重复写入同一提问的证据。

## 客户端原因与修复

1. `ConversationMessages.questions`能将历史`arguments.questionsJson`显示为文字，但`ConversationQuestions.parse`原来只识别实时`items`。因此历史提问没有questions标记，`ConversationMessageMerge`不能用相同commandId/toolCallId替换实时提问。通话结果同步历史后形成两个同文气泡。共享Dart解析补齐items/questions/questionsJson；保留原自然输入、命令和工具身份，不做全局文字去重，不新增表单，不重播历史TTS。
2. `bindConversationCalls.onPhysicalEnded`原来只恢复输入；执行阶段普通tool_card的命令与原确认卡命令不同，不能由原确认卡替换。`ConversationController.onDone`又仅在sending时清理；电话先结束已ready时会跳过清理。现在物理结束清理该外呼提交命令的普通工具，流关闭清理不依赖sending；事件分发不再接纳ready阶段迟到的普通进度。交互工具、确认卡、最终回执和服务端任务状态保留，SSE结束不被当作任务成功。旧电话只清理自身命令，账号/页面/流代际沿用现有隔离。

影响仅为任务对话提问解析和临时进度展示，Android/iOS复用同一Dart实现；未改电话执行、计费、监听、录音、ASR/TTS接口或其他模块。

## 源码依据

| 来源 | 提交与路径 | 依据 |
| --- | --- | --- |
| 旧Android | origin/test/v66.0.3，a0bedb12；android/app/src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/PureVoiceStepPresentationPolicy.kt | 普通工具进度仅流式阶段保留；专用确认/结果出现时隐藏makeCall原始工具展示 |
| 独立App | origin/v71，146152a2；app/src/main/java/com/vvtech/aiassistant/features/assistant_pure_voice/PureVoiceStepPresentationPolicy.kt及PureVoiceConversationStepProjector.kt | 同样清理普通工具；显示合并限制在用户轮次内，后续合法同文不能全局去重 |
| 当前Java | origin/v71，8ebd7db4；aiassistant-agent-sse/src/main/java/com/vvtech/aiassistant/agentsse/assistant/agent/tools/AskUserTool.java | 历史工具参数为title/questionsJson，解析后的实时AskQuestionsPayload使用items；客户端应兼容两者 |
| Flutter | conversation_questions.dart、conversation_message_merge.dart、conversation_call_binding.dart、conversation_controller.dart、conversation_event_flow.dart、conversation_message_store.dart | 复用既有模型、展示覆盖层和finishTools，ledger事实不删改，未建立第二状态机 |

旧AskUserTool注释包含表单描述，但v66正式纯语音UI和用户当前明确要求采用自然回答；本次不恢复表单控件。

## 220已有服务器证据

只读检查`/logs/java/chaken-ai/dev`的Agent日志，时间为服务器北京时间2026-10-10，读取于09:38:43。相关会话日志可观察到：

| 时间 | ledger事实 | sequence | 结果 |
| --- | --- | --- | --- |
| 09:18:04.830 | TOOL_REQUESTED | 10 | created |
| 09:19:02 | TOOL_RESULT_RECORDED / USER_TURN_ACCEPTED | 11 / 12 | created |
| 09:19:04.420 | TOOL_REQUESTED | 13 | created |
| 09:19:18 | TOOL_RESULT_RECORDED / USER_TURN_ACCEPTED | 14 / 15 | created |
| 09:19:21.731 | TOOL_REQUESTED；随后call_ready | 16 | created |
| 09:19:33.685 | tool_card；随后call_started | 不属于ledger事实 | 已观测 |
| 09:20:23 | CALL_OUTCOME_REPORTED | 22 | created |
| 09:20:23.705 | ASSISTANT_TURN_COMMITTED；随后call_finished/task_completed | 23 | created |

seq10与seq13之间有用户答复/工具结果，不能将两个不同轮次的TOOL_REQUESTED当作同一问题重复落库。日志没有保存足以核对提问正文、commandId/toolCallId的完整展示payload；没有据此要求后端修改现有合法接口，也不把事件日志当作音频播放证据。

## 后端同事核对项（未确认故障，不直接要求改代码）

- 如客户端更新后仍重复，请关联用户对应session的`/api/agent/conversations/{sessionId}/timeline`和SSE，核对同一commandId/toolCallId的TOOL_REQUESTED是否只有一个事实；重发应复用eventId/sequence，工具结果不得复执行。提供脱敏身份关联、字段结构及重复次数即可，无需对话/电话正文。
- 保持历史arguments.questionsJson与实时questions.items契约、pendingToolCallId及commandId一致；不必为本次客户端修复将历史字段改为items。
- 核对执行工具进度与callAttemptId/callId归属，以及task_completed/task_failed/流关闭顺序；进度事件不能替代最终回执。如果终态后仍发送“提交中”，请给出相关事件的命令/attempt关联和时间，而不是修改电话状态掩盖展示问题。
- 本文两处客户端展示缺陷不代表此前监听、转写或TTS问题已解决；相关后端待确认见[外呼接口交接](BACKEND_TASK_OUTBOUND_CONTRACTS_20261010.md)及[语音路由诊断](TASK_VOICE_ROUTING_DIAGNOSIS_20261010.md)。

## 验证

固定Flutter3.32.0。新测试先复现questionsJson解析失败、历史双气泡、物理结束残留进度，再验证修复；另验证不同轮次同文保留、旧电话只清理自身命令、迟到普通进度不重现、确认/回执保留和没有额外外呼提交。首轮30项专项及直接调用方通过；最终`flutter test test/features/conversation test/features/calls test/conversation`共1105通过/0失败（含history及导航、双平台主题测试），analyze无问题，OpenSpec35通过。未重复全仓库回归，因为改动限于既有任务对话投影/清理，直接调用方已覆盖。

Android同版本下载镜像构建41.6秒成功，版本46/1.0.51-foundation，包内三个HTTPS开发域名基地址核验通过；仅本次进程切下载镜像，SDK保持3.32.0。`adb install -r`于10:05:34成功覆盖安装，firstInstallTime仍2026-09-18 12:54:52；系统安装成功页只读核对，未卸载、清数据、自动启动、点击任务或拨号。

交付包：`D:\work\04phoneAgent\_isolated\phone-local-runtime\conversation-duplicate-tool-fix-20261010-v46.apk`；SHA256 `D546F9504AC0D837FFD447387E4D8F1AB27ABE780603A3A02DB1E8FDBF7E93AB`。包、原始日志和设备UI XML不纳入Git。

测试均为合成数据。当前真实对话截图复核、普通登录、真实外呼及iOS/macOS构建/真机尚未验证，不能以Dart测试或安装成功替代。
