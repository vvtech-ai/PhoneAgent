# Verification

日期：2026-10-20。当前检出 `codex/dev@8445d06f21f04d3511498b73aa16d7d32bc39867`。未切分支、提交、推送、构建、安装或真实外呼。其他工作人员的改动保持原状。

## 诊断边界

只读打开用户诊断 zip 的唯一 `diagnostics.jsonl`，只筛选停止/取消/中断关键词并输出白名单 `operation/result/time/statusCode/elapsedMs`，未输出请求正文、账号、联系人、凭据或媒体。匹配8行均为 `voiceMedia` 的 started/failed/succeeded，时间为2026-10-19 UTC；该包不足以确定用户现场停止 API 与最终事件的因果顺序。本次根因结论限于源码机制与受控端口回放。

## RED → GREEN

工作目录为 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow`。

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/conversation/stop_transient_header_status_test.dart --reporter expanded
```

初始3例 RED：真实 Controller/页面重复停止时顶部缺少处理状态，实际失败也没有顶部错误。独立暂态接线后3 passed；补充终态身份、迟到回调、取消确认和优先级后最终6个新用例通过：

- Android / iOS 重复点击置灰停止按钮：只有1次 stopBatch，正文/消息身份保持，未决再次点击顶部只同步不重发请求；所属终态到达立即撤暂态，后续定时等待不复活提示。
- 真实停止失败：顶部错误可见，点击后明确重试；成功读取终态后错误清理。
- 其他 batch 的终态不清本次状态；本 batch 终态在 API 返回前到达也能结束暂态，API 迟到失败不能重新污染顶部。
- 拒绝批量确认不发送停止请求并清理本地过渡，保留业务正文和停止入口。
- 原有确认卡恢复错误与结果整理阶段仍优先可见，不覆盖或清空通用 notice。

测试使用真实 ConversationController、binding、消息投影和 ConversationPage；仅网关、停止服务与历史端口受控。Android/iOS 指 ThemeData 的平台 widget 回放，不是真机证据。

## 相邻回归

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/conversation/stop_transient_header_status_test.dart test/features/conversation/conversation_stop_coordinator_test.dart test/features/conversation/conversation_stop_late_event_test.dart test/features/conversation/task_160_stop_test.dart test/features/conversation/batch_progress_recovery_test.dart test/features/conversation/conversation_feedback_prompt_parity_test.dart --reporter expanded
```

结果28 passed，退出码0。最终稳定源码额外合并模型身份邻近组，运行如下16文件命令：

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' test --no-pub test/features/conversation/stop_transient_header_status_test.dart test/features/conversation/conversation_stop_coordinator_test.dart test/features/conversation/conversation_stop_late_event_test.dart test/features/conversation/task_160_stop_test.dart test/features/conversation/batch_progress_recovery_test.dart test/features/conversation/conversation_feedback_prompt_parity_test.dart test/features/conversation/apology_model_operation_identity_test.dart test/features/conversation/apology_voice_flow_test.dart test/features/conversation/apology_committed_timeline_test.dart test/features/conversation/apology_task_model_scope_test.dart test/features/conversation/apology_opening_speech_test.dart test/features/conversation/apology_entry_controller_test.dart test/features/conversation/apology_cancellation_test.dart test/features/conversation/apology_precheck_lifecycle_test.dart test/features/conversation/conversation_message_merge_test.dart test/features/call_models/apology_task_model_sheet_test.dart --reporter expanded
```

结果77 passed，退出码0。既有停止合并、部分失败显式重试、批量身份校验、旧互动隔离、进度恢复、顶部恢复提示、道歉 Consent/切模/首次opening/取消和普通消息合并均通过。

```powershell
& 'D:/tools/flutter-3.32.0/bin/flutter.bat' analyze --no-pub lib/features/conversation/domain/stopping/conversation_stop_coordinator.dart lib/features/conversation/presentation/controller/conversation_stop_binding.dart lib/features/conversation/presentation/controller/conversation_state.dart lib/features/conversation/presentation/controller/conversation_controller.dart lib/features/conversation/presentation/widgets/conversation_status_presentation.dart lib/features/conversation/presentation/pages/conversation_page.dart test/features/conversation/stop_transient_header_status_test.dart test/features/conversation/task_160_stop_test.dart
openspec validate fix-stop-transient-header-status --strict
```

局部静态分析8项 No issues；OpenSpec valid；相关已修改文件 `git diff --check` 无空白错误。中文文案按UTF-8写入并读回正常。

## 实际改动与未验收

- state 增加独立 transientStatus，页面不将其放入 timeline 或 thinking 占位，顶部沿用既有点击动作与状态控件。仅当前停止流程写入此字段，其他模块真实错误不批量迁移或吞掉。
- coordinator 区分已受理未终态与真实失败；未决重复操作只读同步，失败项仍可显式重试。binding 冻结停止目标 batch 并在既有投影回调核对所属终态；新轮次、恢复和关闭失效旧操作。
- 移除因新接线不再使用的 binding.notice 参数；既有 `task_160_stop_test.dart` 仅删除3个对应空回调，不改断言。
- 未执行真实后端、真机画面、实际音频、SIP或停止生产任务，不声明现场已修复或 DEVICE-01 已验收。
