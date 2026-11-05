# 外呼确认与结果等待反馈

## 需求补充

用户 2026-10-16 明确要求：确认外呼后先显示用户说的确认内容，再在旧版已有短暂等待期显示 AI 处理反馈；拨打结束后的结果反馈也参照旧版。只调整展示与既有状态接线，不新增延迟、真实呼叫、结果生成或重复播报。

### Requirement: 确认内容先回显再交接拨号
系统 MUST 对文本、语音和按钮接受的确认内容立即回显一次，并在既有 1500ms 准备期显示准备反馈。MUST 复用同一确认命令身份合并后续权威记录，不把确认文本发送为额外普通 Agent 轮次。重复确认不重发；修改/取消和准入失败仍可处理。

#### Scenario: 用户确认后准备拨打
- **WHEN** 当前确认卡已展示且用户明确确认
- **THEN** 先显示用户确认内容及准备状态，既有计时届满并通过准入后才提交一次 `confirm_call`

### Requirement: 拨后等待权威结果
系统 MUST 在物理通话结束、权威结果未到达时显示结果整理反馈与等待状态。MUST 继续复用真实 thinking、ledger 结果和既有 TTS 去重，不伪造推理/总结，不将物理结束当成业务成功。旧命令思考不得遮挡当前等待反馈。

#### Scenario: 通话结束但结果尚未返回
- **WHEN** 当前通话已进入结果等待阶段
- **THEN** 返回会话并明确显示“正在整理通话结果”，当前命令真实思考可替代通用等待卡；结果到达后移除等待反馈并按现有规则展示/播报一次

## 源码依据与边界

- 原生 `AgentStreamConfirmCallHandler.onConfirm`：先 `appendUserStep`，voice `processingTurn=true`，已有 `delay(1500L)` 后执行。
- 原生 `ConversationCallConfirmationHandler`：显式确认及分类确认共同调用同一确认处理器。
- 原生 `TaskReceiptUiStateReducer.applyCallOutcomePendingDisplay`：物理结束返回会话、processingTurn=true，保持等待权威结果。
- Flutter `CallLaunchCoordinator` 已有 1500ms，不修改其计时、幂等与准入。缺口位于 `conversation_call_binding` 未投影 waiting 且未写本地确认用户消息。
- Flutter 已有 `CallOutcomeScope`、结果等待卡和 `CommittedReplyNarration`。只补页头等待反馈并将思考替代范围限制到当前命令；既有结果排序/语音/物理计时保持。

## 验证记录

1. RED：新增 `call_confirmation_feedback_test.dart`，实现前 5 项全部按预期失败：text/voice/button 缺确认回显，拨后缺页头整理状态。日志 `.local/call-feedback-red.log`。
2. GREEN：新增准备状态投影 `ConversationCallFeedback`，仅监听现有 waiting/checking，不持有 Timer/网络。预留确认 commandId，立即写一次本地用户消息；提交时复用该 ID，ledger 到达替换而非再追加。`ConversationState.preparingCall` 不改变 canSend，取消/准入失败/提交会清理该状态。消息展示及状态投影分别留在小文件，不扩大 ConversationController 或调用核心。
3. `ConversationPage` 在准备期复用通用反馈卡；拨后页头显示整理状态，只有当前命令真实 thinking 替代通用卡。没有新增或伪造思考消息、AI 总结、请求和 TTS。
4. 第一组 7 文件 54 项通过：新增 8 项覆盖文本/ASR/按钮、1499/1500ms、取消/准入失败再确认、ledger 替换和当前/旧 thinking；同时覆盖确认交互、call flow、双平台物理结束/恢复等待、结果播报集成/控制器/去重。旧 call-flow 的“只有一条用户消息”预期改为创建任务和确认各一条，`confirm_call` 仍无普通 message 字段。
5. 第二组 9 文件 51 项通过：thinking UI/流、v66 状态、反馈提示、批量确认/拒绝、语音确认提示、进度规则及不同高度页面回归。合计 105 项，未称全量。
6. 定向 `flutter analyze` 7 个相关实现/测试文件无问题；定向 Dart format、UTF-8 中文读回和 `git diff --check` 通过。日志 `.local/call-feedback-final.log`、`call-feedback-ui-regression.log`、`call-feedback-analyze.log`；新增 8 项的最终补验日志 `call-feedback-confirm-final.log`。

主要命令：

```powershell
flutter test test/features/conversation/call_confirmation_feedback_test.dart test/features/conversation/confirmation_interaction_test.dart test/features/calls/conversation_call_flow_test.dart test/features/calls/conversation_outcome_thinking_test.dart test/features/conversation/voice/result_speech_integration_test.dart test/features/conversation/voice/result_speech_controller_test.dart test/features/conversation/voice/committed_reply_narration_test.dart --reporter expanded
flutter test test/features/conversation/conversation_thinking_ui_test.dart test/features/conversation/conversation_thinking_stream_test.dart test/features/conversation/v66_conversation_status_test.dart test/features/conversation/conversation_feedback_prompt_parity_test.dart test/features/conversation/batch_confirmation_test.dart test/features/conversation/batch_confirmation_rejection_test.dart test/features/conversation/voice/call_confirmation_prompt_integration_test.dart test/features/conversation/conversation_progress_test.dart test/features/conversation/conversation_progress_widget_test.dart --reporter expanded
```

使用固定 Flutter 3.32/Dart 3.8，未打包/安装、真实外呼或访问外部账号。物理通话与真实回执/TTS 效果仍需运行环境验收；共享任务、OpenSpec 总体验证、独立复核及最终签包由主线程集成。
