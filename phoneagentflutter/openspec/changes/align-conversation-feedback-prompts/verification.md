## 源码对照

- 原生：`aiassistant-app` / `feature/test_v1.6.0` / `8f23592`，仅只读核对。
- Flutter：`codex/dev`，主线程先撤销误操作的未推送dev_zys合并；用户随后授权拉取更新后的origin/codex/dev，已快进到b29853ac。本轮不单独再次合并dev_zys。
- 原生空问卷文字：`AgentStreamResponseStepReducer.visibleResponseDisplayText` 和 `AgentStreamInteractiveResponsePolicy.askUser` 均优先 questions.title。
- 原生思考卡：`PureVoiceThreadList` 使用 Phone Agent 标题；`PureVoiceThinkingCardEntryPolicy` 为三种批量技能提供正在理解任务...回退。

## 红测证据

主线程按串行约定实际运行 `test/features/conversation/conversation_feedback_prompt_parity_test.dart`：

1. 首批3项按预期失败：Android/iOS重复恢复长文案、多路卡片前言与语音标题不一致。
2. 首批实现后3项通过；新增思考卡标题/回退测试按预期失败。
3. 思考卡实现后前4项通过；普通空 ASK_USER 在已提交前言后丢失标题测试按预期失败（第159行 expected true / actual false）。

## 首轮绿测

主线程串行运行反馈提示、问题历史合并、自然答复、思考卡、会议重复提问、task_160投影、controller和确认门禁集合，41项全部通过。后续raw final互动、业务短提示及道歉流程集合25项通过；独立审查7文件38项全部通过。analyze无问题，OpenSpec160项通过。

## 最终验证与边界

- 全量发现OCR标题、memory notice等本轮相关15项，均修复并补验39项通过。最终联合回归41文件246项通过、analyze无问题、OpenSpec160通过；剩余12项已在未改b29853ac基线复现，详见主变更回执，不宣称全量通过。
- 没有运行真实短信、联系人读取授权、外呼、计费或设备语音，未修改后端和数据库。
- UI修复不证明截图中真实服务请求异常已修复，真实 errorCode/HTTP/SSE 仍需独立证据。

## 1512追加显示复验

用户提供phoneagent-diagnostics-1792054302588.zip，结构日志时间14:03至16:51，早于1511构建；含ASK_USER但不含原始显示/TTS全文，不能据此推断1511仍失败。将原纯投影测试增强为实际ConversationPage widget测试：投影卡内文字等于SpeechPromptPolicy，同句实际可见一次，截图旧前言不可见、无UI异常。该文件8项全部通过，本轮未改这项生产逻辑。通讯录404根因另有网关证据，见fix-contact-lookup-service-routing。
