# Verification

日期：2026-10-20。检出：`codex/dev@8445d06f21f04d3511498b73aa16d7d32bc39867`。本次不切分支、不提交、不推送、不构建、不真实外呼。其他工作人员的未提交文件保持原状。

## 历史实际测试与目标

- `a0bedb12:android/app/src/test/java/com/vvtech/aiassistant/features/assistant_apology/ApologyVoiceCoordinatorTest.kt`：`initialConsentThenDefaultCloneSwitchIsSilentAndUsesNewAsset` 断言切模后提示数不变；`lateResultFromPreviouslySelectedModelCannotReplaceNewSelection` 保护旧请求隔离。
- `8f235920:app/src/test/java/com/vvtech/aiassistant/features/assistant_apology/ApologyVoiceCoordinatorTest.kt`：`defaultCloneSwitchStopsOldSpeechAndAnnouncesNewModelAndAsset` 改为新提示数 +1；`switchingToMissingVoiceStillAllowsReturningToAnotherReadyModel` 重复两次返回同模型；另保留迟到请求保护。
- 旧版本测试通过 `git show <ref>:<path>` 只读核对，未执行旧项目测试、未修改旧检出。按用户批准例外保留 1.6.0 每次成功切换反馈，并补足 Flutter 的真实 Controller 连续身份回放。

## RED → GREEN

工作目录均为 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow`。

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/conversation/apology_model_operation_identity_test.dart --reporter expanded
```

初始 RED：4 failed，均明确观察到返回模型甲时旧 ready 正文被覆盖。修正 binding 后：4 passed。

独立身份保护 mutation：仅将模型 prompt/card/choice 三类 ID 临时恢复为 modelId（ready 保持修复），运行下列用例 RED：预期两张独立旧卡，实际仅一个 `local:apology:model-choice-card:a` 身份。恢复修复后新文件全绿。

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/conversation/apology_model_operation_identity_test.dart --plain-name 'MODEL-01 returning through the same model choice keeps both locked cards' --reporter expanded
```

扩展 HISTORY-01 的 RED：先保留已修复 binding，运行下列命令，初始 opening 返回后预期 7 条正文实际 6 条，少一条模型乙反馈。仅收紧道歉 prelude 的单个 opening owner 后 GREEN。

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/conversation/apology_model_operation_identity_test.dart --plain-name 'HISTORY-01 initial opening reconciles only the final repeated feedback' --reporter expanded
```

最终新文件 5 passed，覆盖 MODEL-01、MODEL-02、HISTORY-01：全文和身份前缀保持、相同文案重复、旧卡快照和失活、重复回调、真实 signal 建立的 pending、旧查询成功 / 失败迟到、opening 乱序 / 重复以及普通后续 command 的相同文案正文。

## 最终相邻回归

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/conversation/apology_model_operation_identity_test.dart test/features/conversation/apology_voice_flow_test.dart test/features/conversation/apology_committed_timeline_test.dart test/features/conversation/apology_task_model_scope_test.dart test/features/conversation/apology_opening_speech_test.dart test/features/conversation/apology_entry_controller_test.dart test/features/conversation/apology_cancellation_test.dart test/features/conversation/apology_precheck_lifecycle_test.dart test/features/conversation/conversation_message_merge_test.dart test/features/call_models/apology_task_model_sheet_test.dart --reporter expanded
```

结果：49 passed，退出码 0。覆盖首次 opening 的 committed 协调、模型作用域、候选音色 consent、取消确认、切模暂停倒计时、Android / iOS widget 与实际 voice host 开场序列。乱序用例产生预期 `ledger_merge ... expected=3 head=2` 诊断；无失败。

额外扩大范围运行下列命令，输出停在 33 passed 后长时间无后续输出；收到新用户问题后中止，退出码 1。没有完整通过结论，也没有输出具体断言失败；未完成文件为 `pending_tool_restore_test.dart`、`conversation_question_history_merge_test.dart`、`conversation_tool_lifecycle_test.dart`。前 33 项覆盖普通 Controller、fact sync 与 ledger sync，但不计作完整测试组通过。

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/conversation/conversation_controller_test.dart test/features/conversation/conversation_fact_sync_test.dart test/features/conversation/history/ledger_sync_test.dart test/features/conversation/pending_tool_restore_test.dart test/features/conversation/conversation_question_history_merge_test.dart test/features/conversation/conversation_tool_lifecycle_test.dart --reporter expanded
```

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' analyze --no-pub lib/features/apology/presentation/controller/apology_conversation_binding.dart lib/features/conversation/domain/conversation_message_merge.dart test/features/conversation/apology_model_operation_identity_test.dart
openspec validate repair-apology-model-operation-identity --strict
git diff --check -- lib/features/apology/presentation/controller/apology_conversation_binding.dart lib/features/conversation/domain/conversation_message_merge.dart
```

结果：3 项静态分析 No issues；OpenSpec valid；diff 无空白错误。中文内容按 UTF-8 写入并读回正常，仅格式化本次新测试与实际修改的 merge 文件。

## 验收边界

- 源码机制和自动回放已确认；未执行真实后端、Android / iOS 真机、真实可听音频或外呼，不声明 DEVICE-01 已验收。
- 首次 command 当前只提交最新 `initialOpening` / `initialAssistantPrompt` / `initialUserSelection`。本次证明实时消息及返回 opening 协调不丢早期切模反馈，不证明完整退出重建会恢复此前所有本地模型操作；该持久化范围需要后续后端 / 真机事实证据。
- 新逻辑只收紧道歉 prelude 的首次 command anchor；非道歉 SSE / 账本合并分支没有修改，不以全局文本去重、全局重排或取消同事实协调修复。
